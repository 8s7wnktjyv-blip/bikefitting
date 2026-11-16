-- Test Stand 22 (lokal Postgres 16, 16.11.2026): Zählung, Ereignisname bereinigt, falsche App ignoriert, anon darf nicht lesen.
set role anon;
select usage_hit('pass','tool_svc'); select usage_hit('pass','tool_svc'); select usage_hit('pass','Tool SVC!'); select usage_hit('hacker','x');
select usage_stats(30) as anon_liest;
reset role;
select app, event, n from usage_daily where day=current_date order by event;
