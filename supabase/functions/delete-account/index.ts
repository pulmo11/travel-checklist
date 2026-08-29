import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "jsr:@supabase/server@^1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export default {
  fetch: withSupabase(
    { auth: ["publishable", "user"] },
    async (request, { supabase, supabaseAdmin, userClaims }) => {
      if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
      if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

      const userId = typeof userClaims?.sub === "string" ? userClaims.sub : "";
      if (!userId) return json({ error: "authentication_required" }, 401);

      try {
        const payload = await request.json().catch(() => ({}));
        if (payload?.confirmation !== "DELETE") {
          return json({ error: "confirmation_required" }, 400);
        }

        // Feedback images are private objects. Only paths belonging to this
        // authenticated account are selected and removed.
        const { data: feedbackRows, error: feedbackError } = await supabaseAdmin
          .from("feedback")
          .select("screenshot_paths")
          .eq("user_id", userId);
        if (feedbackError) throw new Error("feedback_lookup_failed");

        const paths = (feedbackRows || []).flatMap((row) =>
          Array.isArray(row.screenshot_paths) ? row.screenshot_paths : []
        );
        if (paths.length) {
          const { error: storageError } = await supabaseAdmin.storage
            .from("feedback-images")
            .remove(paths);
          if (storageError) throw new Error("feedback_storage_delete_failed");
        }

        // The RPC runs as one transaction. It transfers shared group ownership
        // when needed and removes only this account's application data.
        const { error: dataError } = await supabase.rpc(
          "delete_festival_passport_account_data",
        );
        if (dataError) throw new Error("account_data_delete_failed");

        const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(
          userId,
          false,
        );
        if (authError) throw new Error("auth_user_delete_failed");

        return json({ deleted: true });
      } catch (error) {
        console.error(
          "Account deletion failed",
          error instanceof Error ? error.message : "unexpected_error",
        );
        return json({ error: "account_delete_failed" }, 500);
      }
    },
  ),
};
