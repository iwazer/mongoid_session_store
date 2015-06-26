Dummy::Application.routes.draw do
  resource :sessions, path: '/' do
    member do
      get :get_session_value
      get :set_session_value
      get :get_session_id
      get :call_reset_session
    end
  end
end
