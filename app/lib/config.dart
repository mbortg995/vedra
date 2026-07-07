/// Configuración de Vedra.
///
/// La clave anon de Supabase es PÚBLICA por diseño (solo lectura, protegida por
/// RLS): es correcta y segura embebida en el cliente, igual que en cualquier web.
class Config {
  static const supabaseUrl = 'https://zstlltvzotxmjjzgczsl.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpzdGxsdHZ6b3R4bWpqemdjenNsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMzMzA3MTQsImV4cCI6MjA5ODkwNjcxNH0.jGyBZQ2v_KXlRCFRNAtX-eWQYmEj0_Ipylk9dl2hUkA';
}
