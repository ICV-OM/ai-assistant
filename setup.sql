-- ═══════════════════════════════════════════════════════════════
-- منظومة "مجيب" — إعداد قاعدة البيانات (يُلصق مرة واحدة)
-- Supabase → SQL Editor → New query → لصق → Run
-- ═══════════════════════════════════════════════════════════════

-- 1) المصادر المعتمدة
create table if not exists mujeeb_documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  file_name text,
  category text default 'عام',
  content text,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2) المقاطع المعرفية (يبحث فيها مجيب)
create table if not exists mujeeb_chunks (
  id uuid primary key default gen_random_uuid(),
  document_id uuid references mujeeb_documents(id) on delete cascade,
  chunk_index int not null,
  content text not null,
  created_at timestamptz default now()
);
create index if not exists idx_chunks_doc on mujeeb_chunks(document_id);

-- 3) النصائح الإدارية اليومية
create table if not exists mujeeb_tips (
  id uuid primary key default gen_random_uuid(),
  tip_text text not null,
  source text,
  day_index int,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- 4) المستخدمون
create table if not exists mujeeb_users (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text unique not null,
  pin text not null,
  role text not null default 'employee' check (role in ('employee','admin')),
  department text,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- 5) سجل المحادثات
create table if not exists mujeeb_conversations (
  id uuid primary key default gen_random_uuid(),
  user_email text,
  question text not null,
  answer text,
  rating int,
  created_at timestamptz default now()
);
create index if not exists idx_conv_date on mujeeb_conversations(created_at desc);

-- 6) الإعدادات
create table if not exists mujeeb_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz default now()
);

insert into mujeeb_settings (key, value) values
 ('assistant_name','مجيب'),
 ('welcome_message','مرحباً! أنا مجيب، مساعدك الذكي في هيئة المشاريع والمناقصات والمحتوى المحلي. اسألني عن قانون الحماية الاجتماعية أو منظومة إجادة لقياس الأداء.'),
 ('answer_scope','strict'),
 ('daily_tip_enabled','true')
on conflict (key) do nothing;

-- حساب المسؤول الافتراضي (غيّر الرمز بعد أول دخول)
insert into mujeeb_users (full_name, email, pin, role, department) values
 ('إبراهيم العلوي','iks.alalawi@gmail.com','1980','admin','تقنية المعلومات')
on conflict (email) do update set role='admin';

-- النصائح الإدارية (15 نصيحة مستمدة من الملفين)
insert into mujeeb_tips (tip_text, source, day_index, is_active) values
('حدّد أهدافك الوظيفية في بداية كل دورة أداء بحيث تكون واضحة وقابلة للقياس ومرتبطة بالخطة السنوية للوحدة — فهي أساس تقييمك في منظومة إجادة.','دليل إجادة — المرحلة الأولى',1,true),
('استغل الجلسة النقاشية مع مسؤولك المباشر: حضّر لها بالأدلة والحقائق التي تبيّن حجم الجهد ونسبة الإنجاز وجودة المخرجات.','دليل إجادة — التظلم وكيفية تفاديه',2,true),
('اطلب التغذية الراجعة من مسؤولك المباشر بشكل دوري ولا تنتظر نهاية دورة التقييم — ثم ضعها موضع التنفيذ.','دليل إجادة — التغذية الراجعة',3,true),
('عند وضع النتائج الرئيسية لأهدافك (OKRs)، حدّد لكل نتيجة وزناً ومستهدفاً بثلاثة مستويات: دون التوقعات، يحقق التوقعات، يفوق التوقعات.','دليل إجادة — إعداد الأهداف',4,true),
('للحصول على مرتبة ممتاز: شارك بفاعلية في أكثر من مشروع أو فريق عمل، وقدّم أعمالاً أو مقترحات قابلة للتطبيق تسهم في تحسين العمل.','دليل إجادة — متطلبات مرتبة ممتاز',5,true),
('وثّق إنجازاتك أولاً بأول مع المستندات الداعمة — عند نهاية الدورة ستحتاج إثبات نسبة الإنجاز الفعلي لكل نتيجة رئيسية.','دليل إجادة — احتساب الإنجاز',6,true),
('إذا واجهت صعوبات أثّرت على تحقيق أهدافك، دوّنها في خانة الملاحظات مع مقترحات لتذليلها في الدورة القادمة.','دليل إجادة — إرشادات عامة',7,true),
('تذكّر: تقييم الأداء يُبنى على الإنجاز الفعلي بعيداً عن الآراء أو السمات الشخصية — ركّز على النتائج الملموسة.','دليل إجادة — الموضوعية',8,true),
('على جهة العمل إبلاغ صندوق الحماية الاجتماعية بأي تغيير يطرأ على المؤمن عليه خلال 14 يوماً من حدوثه.','اللائحة التنفيذية — المادة (2)',9,true),
('التزم بتسجيل كل موظف جديد في فروع التأمين الاجتماعي خلال 30 يوماً من التحاقه بالعمل، وكذلك إنهاء تسجيله عند انتهاء خدمته.','اللائحة التنفيذية — المادة (21)',10,true),
('يحق للموظف الاعتراض على أجر الاشتراك المسجل لدى الصندوق خلال 90 يوماً من تاريخ تسجيل الأجر.','اللائحة التنفيذية — المادة (34)',11,true),
('بدل إجازة الأمومة 98 يوماً وبدل إجازة الأبوة 7 أيام بواقع 100% من الأجر الأخير.','اللائحة التنفيذية — المادة (95)',12,true),
('لاستحقاق بدل الأمان الوظيفي: سجّل في قاعدة بيانات وزارة العمل ونشّط حالتك مرة شهرياً على الأقل، وقدّم طلب الصرف خلال 12 شهراً من انتهاء الخدمة.','اللائحة التنفيذية — المادتان (86) و(88)',13,true),
('كمسؤول مباشر: اجتمع بموظفيك في بداية العام لشرح الخطة السنوية، وتأكد أن أهدافهم تتسم بالوضوح والتحدي وذات صلة بالخطة.','دليل إجادة — الأدوار والمسؤوليات',14,true),
('أفضل دورية للتقييم بحسب الدراسات هي التقييم الربع سنوي — راجع تقدمك نحو أهدافك كل ثلاثة أشهر.','دليل إجادة — دورية التقييم',15,true)
on conflict do nothing;

-- تفعيل الحماية بسياسات مفتوحة عبر anon (التطبيق يدير الأدوار داخلياً)
do $$
declare t text;
begin
  foreach t in array array['mujeeb_documents','mujeeb_chunks','mujeeb_tips','mujeeb_users','mujeeb_conversations','mujeeb_settings']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists "open_all_%s" on %I', t, t);
    execute format('create policy "open_all_%s" on %I for all using (true) with check (true)', t, t);
  end loop;
end $$;

select 'تم إعداد منظومة مجيب بنجاح ✓' as النتيجة;

-- ═══════════════════════════════════════════════════════════════
-- تحديث: حدّ المعدّل للوصول العام (يمنع استنزاف الرصيد)
-- ═══════════════════════════════════════════════════════════════
create table if not exists mujeeb_rate_limit (
  client_id text not null,
  window_start timestamptz not null default now(),
  count int not null default 0,
  primary key (client_id, window_start)
);
create index if not exists idx_rate_window on mujeeb_rate_limit(window_start);

-- جدول قائمة انتظار الملفات الممسوحة ضوئياً (تحتاج OCR)
create table if not exists mujeeb_pending_ocr (
  id uuid primary key default gen_random_uuid(),
  file_name text not null,
  storage_path text,
  status text default 'pending' check (status in ('pending','processing','done','failed')),
  note text,
  created_at timestamptz default now()
);
alter table mujeeb_rate_limit enable row level security;
alter table mujeeb_pending_ocr enable row level security;
drop policy if exists "open_all_mujeeb_rate_limit" on mujeeb_rate_limit;
create policy "open_all_mujeeb_rate_limit" on mujeeb_rate_limit for all using (true) with check (true);
drop policy if exists "open_all_mujeeb_pending_ocr" on mujeeb_pending_ocr;
create policy "open_all_mujeeb_pending_ocr" on mujeeb_pending_ocr for all using (true) with check (true);

-- دلو تخزين للملفات المرفوعة (يُنشأ من لوحة Storage أو عبر هذا الأمر)
insert into storage.buckets (id, name, public) values ('mujeeb-files','mujeeb-files', true)
on conflict (id) do nothing;
