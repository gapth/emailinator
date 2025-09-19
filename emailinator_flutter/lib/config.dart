// Centralized config for Supabase web/app builds
// Values are provided via --dart-define in Flutter builds.

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
// For native/mobile builds, set your deployed web base URL, e.g. https://app.emailinator.app
const publicWebBaseUrl = String.fromEnvironment('PUBLIC_WEB_BASE_URL');
