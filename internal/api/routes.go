package api

import "github.com/go-chi/chi/v5"

func (api *Api) BindRoutes() {
	api.Router.Route("/api", func(r chi.Router) {
		// /api/path
		r.Route("/v1", func(r chi.Router) {
			// /api/v1/path
			r.Route("/users", func(r chi.Router) {
				// /api/v1/users/path
				r.Post("/signup", api.handleSignupUser)
				r.Post("/login", api.handleLoginUser)
				r.Post("/logout", api.handleLogoutUser)
			})
		})
	})
}
