-- core. — полная очистка демо-базы в Supabase Cloud (перед повторным запуском setup-cloud.sql).
-- Удаляет ВСЕ таблицы, функции и данные core. и демо-пользователей. Не запускайте на базе с реальными клиентами.
do $$
declare j record;
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    for j in select jobname from cron.job where jobname like 'core-%' loop
      perform cron.unschedule(j.jobname);
    end loop;
  end if;
end $$;

drop view if exists public.v_client_risk, public.v_clients, public.v_in_gym, public.v_gym_kpi_month,
  public.v_occupancy_hourly, public.public_gyms cascade;
drop table if exists public.audit_log, public.notifications_outbox, public.risk_contacts, public.client_devices,
  public.bookings, public.schedule_items, public.zones, public.visits, public.gym_secrets, public.payments,
  public.freezes, public.memberships, public.membership_plans, public.clients, public.platform_admins,
  public.staff, public.gyms cascade;
drop schema if exists private cascade;

-- функции core. в схеме public (кроме системных)
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('normalize_phone','gym_features','create_gym','sell_membership','freeze_membership','end_freeze',
         'cancel_membership','refund_payment','confirm_refund','start_online_purchase','attach_provider_payment',
         'confirm_online_payment','checkin_manual','checkin_qr','checkout_visit','create_schedule_series','book_class',
         'cancel_booking','cancel_class','mark_booking','import_clients','anonymize_client','mark_contacted','link_account',
         'join_gym','register_device','request_account_deletion','run_maintenance','claim_notifications',
         'complete_notification','admin_find_user','admin_list_gyms','admin_update_gym','gym_occupancy','dashboard_kpi',
         'revenue_by_month','payments_summary','risk_returned_stats')
  loop
    execute format('drop function if exists %s cascade', f.sig);
  end loop;
end $$;

drop type if exists public.staff_role, public.core_plan, public.plan_kind, public.membership_status,
  public.payment_method, public.payment_status, public.visit_method, public.schedule_kind,
  public.booking_status, public.booking_channel cascade;

delete from auth.users where email like '%@demo.core' or phone = '79160000001';
