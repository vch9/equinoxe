(*****************************************************************************)
(* Open Source License                                                       *)
(* Copyright (c) 2021-present Étienne Marais <etienne@maiste.fr>             *)
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

open Lwt.Syntax
module Utils = Equinoxe.Private.Utils
module Json = Equinoxe.Json
module Client = Piaf.Client.Oneshot
module Body = Piaf.Body
module Resp = Piaf.Response

(**** Type definitions ****)

type t = { address : string; token : string }

let token t = t.token
let address t = t.address

(**** Default values ****)

let build_header token =
  let token = if token = "" then [] else [ ("X-Auth-Token", token) ] in
  token @ [ ("Content-Type", "application/json") ]

let equinoxe_default_path = Utils.Sys.path_from_home_dir ".config/equinoxe/"

(***** Helpers *****)

let convert_to_json resp =
  let+ body =
    match resp with
    | Ok resp -> Body.to_string Resp.(resp.body)
    | Error e -> Lwt_result.fail e
  in
  match body with
  | Ok "" -> Json.of_string "{ }"
  | Ok s -> Json.of_string s
  | Error e -> Json.error (Piaf.Error.to_string e)

let token_from_path token_path =
  match Utils.Reader.read_token_opt token_path with
  | None -> raise Not_found
  | Some token -> token

let default_token () =
  let token_path = Filename.concat equinoxe_default_path "token" in
  token_from_path token_path

let get_token = function
  | `Default -> default_token ()
  | `Path token_path -> token_from_path token_path
  | `Str token -> token

(**** Http methode ****)

let get_from t path =
  let headers = build_header t.token in
  let url = Filename.concat t.address path |> Uri.of_string in
  Client.get ~headers url

let post_from t ~path body =
  let headers = build_header t.token in
  let url = Filename.concat t.address path |> Uri.of_string in
  let body = Body.of_string body in
  Client.post ~headers ~body url

let put_from t ~path body =
  let headers = build_header t.token in
  let url = Filename.concat t.address path |> Uri.of_string in
  let body = Body.of_string body in
  Client.put ~headers ~body url

let delete_from t path =
  let headers = build_header t.token in
  let url = Filename.concat t.address path |> Uri.of_string in
  Client.delete ~headers url

(**** API ****)

let create ~address ?(token = `Default) () =
  let token = get_token token in
  { address; token }

let get t ~path () =
  let* resp = get_from t path in
  convert_to_json resp

let post t ~path json =
  match Json.export json with
  | Ok body ->
      let* resp = post_from t ~path body in
      convert_to_json resp
  | Error (`Msg e) -> Lwt.return @@ Json.error e

let put t ~path json =
  match Json.export json with
  | Ok body ->
      let* resp = put_from t ~path body in
      convert_to_json resp
  | Error (`Msg e) -> Lwt.return @@ Json.error e

let delete t ~path () =
  let* resp = delete_from t path in
  convert_to_json resp

let run json = Lwt_main.run json
