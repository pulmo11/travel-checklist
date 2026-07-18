import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "jsr:@supabase/server@^1";

const ALLOWED_TYPES = new Set(["bug", "feature", "question", "other"]);
const TYPE_LABELS: Record<string, string> = {
  bug: "버그 신고",
  feature: "기능 제안",
  question: "사용 문의",
  other: "기타",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });
}

function escapeHtml(value: unknown) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

export default {
  fetch: withSupabase({ auth: ["publishable", "user"] }, async (request, { supabase }) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const payload = await request.json();
    if (
      !ALLOWED_TYPES.has(payload?.type) ||
      typeof payload?.title !== "string" || payload.title.trim().length < 2 || payload.title.length > 100 ||
      typeof payload?.message !== "string" || payload.message.trim().length < 10 || payload.message.length > 3000 ||
      typeof payload?.email !== "string" || payload.email.length > 254 ||
      !Array.isArray(payload?.screenshot_paths) || payload.screenshot_paths.length > 3
    ) return json({ error: "invalid_input" }, 400);

    const { error: insertError } = await supabase.from("feedback").insert(payload);
    if (insertError) {
      console.error("Feedback insert failed", insertError.code);
      return json({ error: "save_failed" }, 400);
    }

    const resendKey = Deno.env.get("RESEND_API_KEY");
    const notificationEmail = Deno.env.get("FEEDBACK_NOTIFICATION_EMAIL");
    let notificationSent = false;
    if (resendKey && notificationEmail) {
      const emailResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          from: "Festival Passport <onboarding@resend.dev>",
          to: [notificationEmail],
          subject: `[Festival Passport] ${TYPE_LABELS[payload.type]} · ${payload.title.replace(/[\r\n]+/g, " ")}`,
          html: `<h2>새 피드백이 접수되었습니다.</h2>
            <p><strong>유형:</strong> ${escapeHtml(TYPE_LABELS[payload.type])}</p>
            <p><strong>제목:</strong> ${escapeHtml(payload.title)}</p>
            <p><strong>회신 이메일:</strong> ${escapeHtml(payload.email)}</p>
            <p><strong>내용:</strong><br>${escapeHtml(payload.message).replaceAll("\n", "<br>")}</p>
            <p><strong>첨부 이미지:</strong> ${payload.screenshot_paths.length}장</p>
            <p><strong>접수 화면:</strong> ${escapeHtml(payload.page_path || "미등록")}</p>
            <p>상세 정보와 비공개 이미지는 Supabase Dashboard의 feedback 테이블과 feedback-images 버킷에서 확인하세요.</p>`,
        }),
      });
      notificationSent = emailResponse.ok;
      if (!emailResponse.ok) console.error("Feedback notification failed", emailResponse.status);
    } else {
      console.error("Feedback notification secrets are missing");
    }

    return json({ saved: true, notification_sent: notificationSent });
  } catch {
    return json({ error: "unexpected_error" }, 500);
  }
  }),
};
