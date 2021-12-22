(*****************************************************************************)
(* Open Source License                                                       *)
(* Copyright (c) 2021 Étienne Marais <etienne@maiste.fr>                     *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

module type API = sig
  (** It is the signature of the API of the website. *)

  type t
  (** Abstract type [t] represents the information known by the API system. *)

  val create :
    endpoint:string ->
    ?token:[ `Default | `Str of string | `Path of string ] ->
    unit ->
    t
  (** [create opts] returns an {!t} object, you need to manipulate when
      executing requests. *)

  (** This module manages API part related to the user. *)
  module Users : sig
    val get_me : t -> Json.t
    (** [get_me t] returns informations about the user linked to the API key. *)

    val get_api_keys : t -> Json.t
    (** [get_api__keys t] returns the keys available for the current user. *)

    val add_api_key : t -> ?read_only:bool -> string -> Json.t
    (** [add_api_key t ~read_only description] creates a new API key on Equinix.
        Default value to read_only is true. *)

    val del_api_key : t -> string -> Json.t
    (** [del_api_key t key_id ] deletes the key referenced by [key_id] from the
        user keys. *)
  end

  module Orga : sig
    val get_all : t -> Json.t
    (** [get_all t] returns an all the organizations associated with the token. *)

    val get_specific : t -> string -> Json.t
    (** [get_specific t id] returns the {!Json.t} that is referenced by the id
        given in parameter. *)
  end

  module Metal : sig end
end

module type S = CallAPI.S

module type Sigs = sig
  (** Equinoxe library interface. *)

  (** {1 Manipulate Results} *)

  module Json = Json

  module type API = API

  (** {1 Build your own API} *)

  module type S = S

  module Default_api : S

  (** Factory to build a system to communicate with Equinix API, using the {!S}
      communication system. *)
  module Make (C : S) : API
end