-- Возврат клиентов в деньгах и автоматическая отправка в WhatsApp Business

-- Статистика «в зоне риска»: сколько клиентов связались, сколько вернулись и сколько они заплатили после первого контакта
create or replace function public.risk_returned_stats(p_gym uuid, p_from date default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_from timestamptz;
begin
  perform private.require_staff(p_gym, null, false);
  v_from := coalesce(p_from::timestamp at time zone (select timezone from public.gyms where id = p_gym),
                     now() - interval '30 days');
  return (
    with first_contact as (
      select client_id, min(contacted_at) as at, bool_or(returned_at is not null) as returned
        from public.risk_contacts
       where gym_id = p_gym and contacted_at >= v_from
       group by client_id
    )
    select jsonb_build_object(
      'contacted', count(*),
      'returned', count(*) filter (where fc.returned),
      'revenue', coalesce((
        select sum(p.amount)
          from public.payments p
          join first_contact f on f.client_id = p.client_id
         where p.gym_id = p_gym and p.status = 'succeeded' and p.refund_of_id is null and p.paid_at >= f.at
      ), 0))
      from first_contact fc
  );
end $$;

-- Ключи WhatsApp Business (Cloud API): номер отправителя, токен (зашифрован), одобренный шаблон сообщения
alter table public.gym_secrets
  add column whatsapp_phone_id text,
  add column whatsapp_token_encrypted text,
  add column whatsapp_template text,
  add column whatsapp_lang text not null default 'en';

-- Флаг «WhatsApp подключён» без раскрытия ключей — для интерфейса сотрудников
create or replace function public.whatsapp_connected(p_gym uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  perform private.require_staff(p_gym, null, false);
  return exists (select 1 from public.gym_secrets
                  where gym_id = p_gym and whatsapp_phone_id is not null and whatsapp_token_encrypted is not null
                    and whatsapp_template is not null);
end $$;

revoke execute on function public.whatsapp_connected(uuid) from public, anon;
grant execute on function public.whatsapp_connected(uuid) to authenticated, service_role;
grant execute on function public.risk_returned_stats(uuid, date) to authenticated, service_role;
