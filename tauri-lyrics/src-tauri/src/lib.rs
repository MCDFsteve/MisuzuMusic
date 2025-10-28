use axum::{
    extract::State as AxumState,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::{
    net::SocketAddr,
    sync::{Arc, Mutex},
};
#[cfg(target_os = "macos")]
use tauri::ActivationPolicy;
use tauri::{webview::Color, AppHandle, Emitter, Manager, State};
use tokio::net::TcpListener;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LyricsPayload {
    pub track_id: Option<String>,
    pub title: Option<String>,
    pub artist: Option<String>,
    pub active_line: Option<String>,
    pub next_line: Option<String>,
    pub position_ms: Option<u64>,
    pub is_playing: Option<bool>,
    pub active_segments: Option<Vec<FuriganaSegment>>,
    pub next_segments: Option<Vec<FuriganaSegment>>,
    pub active_translation: Option<String>,
    pub next_translation: Option<String>,
    pub show_translation: Option<bool>,
}

#[derive(Clone, Default)]
struct SharedLyricsState(Arc<Mutex<LyricsPayload>>);

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct FuriganaSegment {
    pub original: Option<String>,
    pub annotation: Option<String>,
    #[serde(rename = "type")]
    pub segment_type: Option<String>,
}

#[derive(Clone)]
struct HttpServerState {
    shared: SharedLyricsState,
    app: AppHandle,
}

impl HttpServerState {
    fn new(shared: SharedLyricsState, app: AppHandle) -> Self {
        Self { shared, app }
    }

    fn clone_payload(&self) -> Result<LyricsPayload, String> {
        self.shared
            .0
            .lock()
            .map(|guard| guard.clone())
            .map_err(|_| "无法读取歌词状态".to_string())
    }

    fn update_payload(&self, payload: LyricsPayload) -> Result<LyricsPayload, String> {
        {
            let mut guard = self
                .shared
                .0
                .lock()
                .map_err(|_| "无法获取歌词状态锁".to_string())?;
            *guard = payload.clone();
        }

        if let Err(err) = self.app.emit("lyrics:update", payload.clone()) {
            log::error!("广播歌词更新失败: {err}");
            return Err(err.to_string());
        }

        Ok(payload)
    }
}

const LYRICS_SERVER_PORT: u16 = 21387;

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

#[tauri::command]
fn exit_app(app: AppHandle) -> Result<(), ()> {
    app.exit(0);
    Ok(())
}

async fn start_http_server(state: HttpServerState) -> Result<(), String> {
    let router = Router::new()
        .route("/health", get(handle_health))
        .route("/lyrics", get(handle_get_lyrics).post(handle_post_lyrics))
        .route("/show", post(handle_show_window))
        .with_state(state.clone());

    let address = SocketAddr::from(([127, 0, 0, 1], LYRICS_SERVER_PORT));
    let listener = TcpListener::bind(address)
        .await
        .map_err(|err| format!("绑定桌面歌词端口失败: {err}"))?;

    log::info!("桌面歌词服务已启动，监听 {address}");

    axum::serve(listener, router)
        .await
        .map_err(|err| format!("桌面歌词服务意外退出: {err}"))
}

async fn handle_health() -> impl IntoResponse {
    log::info!("收到桌面歌词健康检查");
    println!("[LyricsServer] /health");
    (StatusCode::OK, Json(serde_json::json!({ "status": "ok" })))
}

async fn handle_get_lyrics(
    AxumState(state): AxumState<HttpServerState>,
) -> Result<impl IntoResponse, (StatusCode, String)> {
    log::info!("收到桌面歌词查询请求");
    println!("[LyricsServer] /lyrics (GET)");
    state
        .clone_payload()
        .map(|payload| (StatusCode::OK, Json(payload)))
        .map_err(|err| (StatusCode::INTERNAL_SERVER_ERROR, err))
}

async fn handle_post_lyrics(
    AxumState(state): AxumState<HttpServerState>,
    Json(payload): Json<LyricsPayload>,
) -> Result<impl IntoResponse, (StatusCode, String)> {
    log::info!("收到桌面歌词更新请求: {:?}", payload);
    println!(
        "[LyricsServer] /lyrics (POST) => active_line={:?}",
        payload.active_line
    );
    state
        .update_payload(payload)
        .map(|payload| (StatusCode::OK, Json(payload)))
        .map_err(|err| (StatusCode::INTERNAL_SERVER_ERROR, err))
}

async fn handle_show_window(
    AxumState(state): AxumState<HttpServerState>,
) -> Result<impl IntoResponse, (StatusCode, String)> {
    if let Some(window) = state.app.get_webview_window("main") {
        log::info!("收到桌面歌词窗口显示请求");
        println!("[LyricsServer] /show");
        if let Err(err) = window.center() {
            log::warn!("居中桌面歌词窗口失败: {err}");
        }
        window
            .show()
            .map_err(|err| (StatusCode::INTERNAL_SERVER_ERROR, err.to_string()))?;
        if let Err(err) = window.set_focus() {
            log::warn!("设置桌面歌词窗口焦点失败: {err}");
        }
    } else {
        return Err((StatusCode::NOT_FOUND, "找不到桌面歌词窗口".to_string()));
    }

    Ok((
        StatusCode::OK,
        Json(serde_json::json!({ "status": "shown" })),
    ))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(SharedLyricsState::default())
        .invoke_handler(tauri::generate_handler![
            update_lyrics,
            get_lyrics_state,
            exit_app
        ])
        .setup(|app| {
            #[cfg(target_os = "macos")]
            {
                let _ = app.set_activation_policy(ActivationPolicy::Accessory);
            }

            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_background_color(Some(Color(0, 0, 0, 0)));
                let _ = window.set_skip_taskbar(true);

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

            let shared_state = app.state::<SharedLyricsState>();
            let http_state = HttpServerState::new(
                SharedLyricsState(shared_state.0.clone()),
                app.handle().clone(),
            );

            tauri::async_runtime::spawn(async move {
                if let Err(err) = start_http_server(http_state).await {
                    log::error!("桌面歌词服务启动失败: {err}");
                }
            });

            let handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                if let Err(err) = tokio::signal::ctrl_c().await {
                    log::error!("等待 Ctrl+C 信号失败: {err}");
                }
                handle.exit(0);
            });
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
