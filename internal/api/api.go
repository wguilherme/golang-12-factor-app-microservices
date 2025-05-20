package api

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

type Api struct {
	// user service
	// router
	Router *chi.Mux
}

func (api *Api) handleCreateUser(w http.ResponseWriter, r *http.Request) {

}
