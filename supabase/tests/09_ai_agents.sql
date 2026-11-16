-- ИИ-агенты: настройка прав, ключи внешних агентов, действия от имени сотрудника, очередь подтверждения
begin;
\ir local/fixture.sql

create or replace function tests.assert(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if p_cond is not true then raise exception 'ПРОВАЛ: %', p_msg; end if;
end $$;
grant execute on all functions in schema tests to authenticated, service_role;
create temp table agent_key (k text);
grant all on agent_key to authenticated, service_role;

-- владелец создаёт агента; неизвестный инструмент и «подтверждение» для чтения не принимаются
select tests.login(tests.id('owner_a'));
select tests.expect_error(format($q$select public.ai_agent_save(%L, null, 'А', 'builtin', 'custom', '', '', '{"drop_db":"auto"}', 'off', true)$q$, tests.id('gym_a')), 'INVALID_INPUT');
select tests.expect_error(format($q$select public.ai_agent_save(%L, null, 'А', 'builtin', 'custom', '', '', '{"find_clients":"approve"}', 'off', true)$q$, tests.id('gym_a')), 'INVALID_INPUT');
select tests.put('agent', public.ai_agent_save(tests.id('gym_a'), null, 'Удержание', 'external', 'retention', 'Будь вежлив', '',
  '{"find_clients":"auto","client_details":"auto","log_contact":"auto","add_client_note":"approve","book_class":"off"}', 'off', true));
select tests.assert((select tools = '{"find_clients":"auto","client_details":"auto","log_contact":"auto","add_client_note":"approve"}'
                       and acts_as = tests.id('owner_a') from public.ai_agents where id = tests.id('agent')), 'агент сохранён, выключенные инструменты не хранятся');
insert into agent_key select public.ai_agent_create_key(tests.id('agent'));
select tests.assert((select k like 'core_ak_%' and length(k) = 56 from agent_key), 'ключ выпущен');
select tests.assert((select count(*) = 1 from public.ai_agent_keys where agent_id = tests.id('agent')), 'владелец видит ключ');
select tests.expect_error('select key_hash from public.ai_agent_keys', '42501');
select tests.expect_error(format('select public.agent_tool(%L, ''find_clients'', ''{}'')', tests.id('agent')), '42501');
reset role;

-- ресепшен агентов не настраивает и не видит; владелец другого зала тоже
select tests.login(tests.id('reception_a'));
select tests.expect_error(format($q$select public.ai_agent_save(%L, null, 'Б', 'builtin', 'custom', '', '', '{}', 'off', true)$q$, tests.id('gym_a')), 'FORBIDDEN');
select tests.assert((select count(*) = 0 from public.ai_agents), 'ресепшен не видит агентов');
reset role;
select tests.login(tests.id('owner_b'));
select tests.assert((select count(*) = 0 from public.ai_agents), 'чужой зал не видит агентов');
select tests.expect_error(format('select public.ai_agent_create_key(%L)', tests.id('agent')), 'FORBIDDEN');
reset role;

-- сервер платформы: агент по ключу, инструменты от имени владельца
set role service_role;
select tests.assert((select public.ai_agent_by_key(k) ->> 'id' = tests.id('agent')::text from agent_key), 'агент найден по ключу');
select tests.expect_error('select public.ai_agent_by_key(''core_ak_wrong'')', 'UNAUTHORIZED');
select tests.assert(jsonb_array_length(public.agent_tool(tests.id('agent'), 'find_clients', '{"query":"Петров"}')) = 1, 'поиск клиента');
select tests.assert(public.agent_tool(tests.id('agent'), 'find_clients', '{"query":"916 123"}') -> 0 ->> 'full_name' = 'Иван Петров', 'поиск по телефону');
select tests.expect_error(format('select public.agent_tool(%L, ''client_details'', %L)', tests.id('agent'),
  jsonb_build_object('client_id', tests.id('client_b1'))), 'CLIENT_NOT_FOUND');
select tests.expect_error(format('select public.agent_tool(%L, ''book_class'', %L)', tests.id('agent'),
  jsonb_build_object('client_id', tests.id('client_a1'), 'class_id', tests.id('class_a'))), 'TOOL_DISABLED');
select tests.expect_error(format('select public.agent_tool(%L, ''client_details'', ''{"client_id":"abc"}'')', tests.id('agent')), 'INVALID_INPUT');
select tests.put('contact', (public.agent_tool(tests.id('agent'), 'log_contact',
  jsonb_build_object('client_id', tests.id('client_a1'), 'reason', 'gone', 'channel', 'call', 'note', 'Позвонил ИИ')) ->> 'contact_id')::uuid);
reset role;
select tests.assert((select s.user_id = tests.id('owner_a') from public.risk_contacts r join public.staff s on s.id = r.staff_id
                      where r.id = tests.id('contact')), 'контакт записан от имени владельца');

-- очередь подтверждения: заметка ждёт сотрудника
set role service_role;
with x as (insert into public.ai_agent_actions (gym_id, agent_id, tool, args, reason, status)
  values (tests.id('gym_a'), tests.id('agent'), 'add_client_note', jsonb_build_object('client_id', tests.id('client_a1'), 'note', 'Хочет утренние тренировки'),
          'Клиент сказал по телефону', 'pending') returning id)
select tests.put('action', id) from x;
reset role;
select tests.login(tests.id('reception_a'));
select tests.expect_error(format('select public.ai_action_claim(%L)', tests.id('action')), 'FORBIDDEN');
reset role;
select tests.login(tests.id('admin_a'));
select tests.assert(public.ai_action_claim(tests.id('action')) ->> 'tool' = 'add_client_note', 'администратор взял действие');
select tests.expect_error(format('select public.ai_action_claim(%L)', tests.id('action')), 'ACTION_DECIDED');
select public.ai_tool(tests.id('gym_a'), 'add_client_note', (select args from public.ai_agent_actions where id = tests.id('action')));
select public.ai_action_finish(tests.id('action'), true, '{"ok":true}');
reset role;
select tests.assert((select note like '%ИИ-агент: Хочет утренние тренировки' from public.clients where id = tests.id('client_a1')), 'заметка добавлена');
select tests.assert((select status = 'executed' and decided_by = tests.id('admin_a') from public.ai_agent_actions where id = tests.id('action')), 'действие выполнено');

-- агент, настроенный администратором, останавливается, когда тот перестаёт быть администратором
select tests.login(tests.id('admin_a'));
select tests.put('agent2', public.ai_agent_save(tests.id('gym_a'), null, 'Аналитик', 'builtin', 'analyst', '', '', '{"gym_stats":"auto"}', 'off', true));
reset role;
set role service_role;
select tests.assert(public.agent_tool(tests.id('agent2'), 'gym_stats') is not null, 'аналитик видит показатели');
reset role;
update public.staff set role = 'reception' where user_id = tests.id('admin_a') and gym_id = tests.id('gym_a');
set role service_role;
select tests.expect_error(format('select public.agent_tool(%L, ''gym_stats'')', tests.id('agent2')), 'AGENT_OWNER_GONE');
reset role;

-- отозванный ключ не работает, выключенный агент тоже
select tests.login(tests.id('owner_a'));
select public.ai_agent_revoke_key((select id from public.ai_agent_keys where agent_id = tests.id('agent')));
reset role;
set role service_role;
select tests.expect_error(format('select public.ai_agent_by_key(%L)', (select k from agent_key)), 'UNAUTHORIZED');
reset role;
update public.ai_agents set enabled = false where id = tests.id('agent');
set role service_role;
select tests.expect_error(format('select public.agent_tool(%L, ''find_clients'')', tests.id('agent')), 'AGENT_DISABLED');
reset role;

select 'ai agents: OK' as result;
rollback;
