import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "jsr:@supabase/server@^1";
import { createClient } from "jsr:@supabase/supabase-js@2";

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
    async (request, { supabaseAdmin }) => {
      if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
      if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

      const accessToken = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
      const { data: authData } = accessToken
        ? await supabaseAdmin.auth.getUser(accessToken)
        : { data: { user: null } };
      const userId = authData.user?.id ?? "";
      if (!userId) return json({ error: "authentication_required" }, 401);

      const userClient = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        {
          global: { headers: { Authorization: `Bearer ${accessToken}` } },
          auth: { persistSession: false, autoRefreshToken: false },
        },
      );

      try {
        const payload = await request.json().catch(() => ({}));
        if (payload?.confirmation !== "DELETE") {
          return json({ error: "confirmation_required" }, 400);
        }

        // Prepare only shared ownership and capture every Storage object owned
        // by this account, including an image not linked to a feedback row.
        const { data: prepared, error: prepareError } = await userClient.rpc(
          "prepare_festival_passport_account_deletion",
        );
        if (prepareError || !prepared?.prepared) {
          throw new Error("account_deletion_prepare_failed");
        }

        const paths = Array.isArray(prepared.image_paths)
          ? prepared.image_paths.filter((path: unknown): path is string =>
            typeof path === "string" && path.length > 0
          )
          : [];
        // Personal rows remain untouched until this succeeds. Their verified
        // auth.users ON DELETE CASCADE FKs then remove them atomically.
        const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(
          userId,
          false,
        );
        if (authError) throw new Error("auth_user_delete_failed");

        // Paths were captured while ownership still existed. Remove the actual
        // Storage objects only after Auth deletion succeeds, so an Auth failure
        // never leaves personal application data partially deleted.
        if (paths.length) {
          const { error: storageError } = await supabaseAdmin.storage
            .from("feedback-images")
            .remove(paths);
          if (storageError) {
            console.error("Account image cleanup failed after Auth deletion");
          }
        }

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
