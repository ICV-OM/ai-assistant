// دالة مجيب السحابية — تُنشر في Supabase Edge Functions باسم: mujeeb-chat
// الأسرار المطلوبة: ANTHROPIC_API_KEY
// verify_jwt = false  (وصول عام — الحماية عبر rate limit)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-client-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// حدّ المعدّل: 20 سؤالاً لكل جهاز في نافذة 3 ساعات
const RATE_MAX = 20;
const RATE_WINDOW_MS = 3 * 60 * 60 * 1000;

const STOP = new Set(["في","من","على","عن","إلى","الى","ما","هل","هو","هي","أن","ان","التي","الذي","مع","كم","متى","كيف","أو","او","ثم","لا","لم","لن","قد","كل","بعد","قبل","عند","هذا","هذه","ذلك","يتم","وفق","حسب"]);
const kws = (q: string) => q.replace(/[؟?،,.:؛]/g," ").split(/\s+/)
  .map(w => w.replace(/^(ال|و|ب|ل|لل|بال|وال)/,""))
  .filter(w => w.length >= 3 && !STOP.has(w)).slice(0,8);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { question, history = [], user_email = null, client_id = "anon" } = await req.json();
    if (!question) throw new Error("السؤال مطلوب");
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // ── حدّ المعدّل لكل جهاز ──
    const now = Date.now();
    const winStart = new Date(Math.floor(now / RATE_WINDOW_MS) * RATE_WINDOW_MS).toISOString();
    const { data: rl } = await sb.from("mujeeb_rate_limit")
      .select("count").eq("client_id", client_id).eq("window_start", winStart).maybeSingle();
    const used = rl?.count ?? 0;
    if (used >= RATE_MAX) {
      return new Response(JSON.stringify({ error: "بلغت الحدّ المسموح من الأسئلة مؤقتاً. يرجى المحاولة بعد قليل." }),
        { status: 429, headers: { ...cors, "Content-Type": "application/json" } });
    }
    await sb.from("mujeeb_rate_limit").upsert({ client_id, window_start: winStart, count: used + 1 });

    // ── البحث في قاعدة المعرفة ──
    const K = kws(question);
    let chunks: { content: string }[] = [];
    if (K.length) {
      const { data } = await sb.from("mujeeb_chunks").select("content")
        .or(K.map(k => `content.ilike.%${k}%`).join(",")).limit(60);
      chunks = (data ?? [])
        .map(c => ({ c, s: K.reduce((n,k)=>n+(c.content.includes(k)?1:0),0) }))
        .sort((a,b)=>b.s-a.s).slice(0,14).map(x=>x.c);
    }
    if (!chunks.length) {
      const { data } = await sb.from("mujeeb_chunks").select("content").limit(10);
      chunks = data ?? [];
    }
    const context = chunks.map(c=>c.content).join("\n\n---\n\n").slice(0,45000);

    const { data: st } = await sb.from("mujeeb_settings").select("key,value");
    const S: Record<string,string> = {};
    (st ?? []).forEach((s: any) => S[s.key] = s.value);

    const system = `أنت "${S.assistant_name ?? "مجيب"}"، المساعد الذكي الرسمي لهيئة المشاريع والمناقصات والمحتوى المحلي في سلطنة عُمان.
قواعد صارمة:
1. أجب فقط من المصادر المرفقة أدناه.
2. إذا لم تجد الإجابة قل: "لا تتوفر هذه المعلومة في المصادر المعتمدة لديّ، أنصحك بمراجعة الجهة المختصة." ولا تجتهد.
3. اذكر دائماً المصدر في نهاية الرد بسطر يبدأ بـ "المصدر:".
4. أجب بالعربية الفصحى المبسطة بأسلوب مهني ودود وموجز.
${S.answer_scope === "assist" ? "5. يمكنك تقديم نصائح إدارية عامة مستندة لدليل إجادة." : ""}

المصادر المعتمدة:
${context}`;

    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "content-type":"application/json", "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!, "anthropic-version":"2023-06-01" },
      body: JSON.stringify({ model: "claude-sonnet-4-6", max_tokens: 1500, system,
        messages: [...history.slice(-6), { role: "user", content: question }] }),
    });
    const data = await resp.json();
    if (!resp.ok) throw new Error(data?.error?.message ?? "فشل الاتصال بالنموذج");
    const answer = (data.content ?? []).filter((b:any)=>b.type==="text").map((b:any)=>b.text).join("\n");

    await sb.from("mujeeb_conversations").insert({ question, answer, user_email });
    return new Response(JSON.stringify({ answer, remaining: RATE_MAX - used - 1 }),
      { headers: { ...cors, "Content-Type":"application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as Error)?.message ?? e) }),
      { status: 400, headers: { ...cors, "Content-Type":"application/json" } });
  }
});
