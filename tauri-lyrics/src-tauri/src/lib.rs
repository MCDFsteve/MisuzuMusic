use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use tauri::{webview::Color, AppHandle, Emitter, Manager, State};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LyricsPayload {
    pub track_id: Option<String>,
    pub title: Option<String>,
    pub artist: Option<String>,
    pub active_line: Option<String>,
    pub next_line: Option<String>,
    pub position_ms: Option<u64>,
    pub is_playing: Option<bool>,
}

#[derive(Default)]
struct SharedLyricsState(Mutex<LyricsPayload>);

#[tauri::command]
async fn update_lyrics(
    state: State<'_, SharedLyricsState>,
    app: AppHandle,
    payload: LyricsPayload,
) -> Result<(), String> {
    {
        let mut guard = state
            .0
            .lock()
            .map_err(|_| "无法获取歌词状态锁".to_string())?;
        *guard = payload.clone();
    }

    app.emit("lyrics:update", payload)
        .map_err(|err| err.to_string())
}

#[tauri::command]
async fn get_lyrics_state(state: State<'_, SharedLyricsState>) -> Result<LyricsPayload, String> {
    state
        .0
        .lock()
        .map(|guard| guard.clone())
        .map_err(|_| "无法读取歌词状态".to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(SharedLyricsState::default())
        .invoke_handler(tauri::generate_handler![update_lyrics, get_lyrics_state])
        .setup(|app| {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_background_color(Some(Color(0, 0, 0, 0)));

                #[cfg(target_os = "macos")]
                {
                    use window_vibrancy::apply_vibrancy;
                    let _ = apply_vibrancy(
                        &window,
                        window_vibrancy::NSVisualEffectMaterial::HudWindow,
                        None,
                        None,
                    );
                }

                #[cfg(target_os = "windows")]
                {
                    use window_vibrancy::{apply_accent, AccentState};
                    let _ = apply_accent(&window, AccentState::Fluent);
                }

                let _ = window.set_ignore_cursor_events(false);
            }

            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
