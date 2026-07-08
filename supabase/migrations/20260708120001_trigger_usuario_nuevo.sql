-- Auth · Crear la fila en `usuarios` al registrarse en Supabase Auth
--
-- La RLS de `usuarios` / `licencias_usuario` se ata a auth.uid(). Cuando alguien
-- se da de alta, Supabase Auth crea la fila en `auth.users`; necesitamos su fila
-- espejo en `public.usuarios` con el MISMO id para que pueda tener licencias.
--
-- Un trigger SECURITY DEFINER lo hace de forma fiable: corre con privilegios del
-- creador y se salta la RLS (que solo permite *select* al dueño, sin *insert*).
-- Idempotente (on conflict do nothing) por si el id ya existiera.

create or replace function public.crear_usuario_para_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.usuarios (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.crear_usuario_para_auth();
