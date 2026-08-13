-- Run only AFTER GEMINI_API_KEY is saved in Edge Function secrets
-- and process-prescription has been deployed successfully.

begin;

update public.ai_provider_configs
set is_active = false
where provider_type <> 'gemini';

update public.ai_provider_configs
set
  model = 'gemini-3.6-flash',
  enabled = true,
  is_active = true,
  timeout_seconds = 60,
  max_retries = 1,
  updated_at = now()
where provider_type = 'gemini';

update public.app_settings
set
  ai_enabled = true,
  maintenance_mode = false,
  updated_at = now()
where id = 1;

commit;
