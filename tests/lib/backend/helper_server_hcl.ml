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
module Json = Equinoxe.Json
open Json.Infix

let extract_body body =
  let open Httpaf in
  let buffer = Buffer.create 1024 in
  let on_read str ~off:_ ~len:_ =
    Bigstringaf.to_string str |> Buffer.add_string buffer
  in
  let on_eof () = () in
  Body.schedule_read body ~on_eof ~on_read;
  Buffer.contents buffer

(* Many assert false as this is not supposed to test the web server but
   the API *)
let request_handler _ reqd =
  let open Httpaf in
  let request = Reqd.request reqd in
  let request_body = Reqd.request_body reqd in
  let body = extract_body request_body in
  match request with
  | { Request.meth = `GET; _ } ->
      let body =
        Json.create () -+> ("id", ~$1.0) |> Json.export |> function
        | Ok body -> body
        | _ -> assert false
      in
      Reqd.respond_with_string reqd (Response.create `OK) body
  | { Request.meth = `POST | `PUT; _ } ->
      let json = Json.of_string body in
      let userId =
        json --> "userId" |> Json.to_float_r |> function
        | Ok i -> i
        | _ -> assert false
      in
      let body =
        Json.create () -+> ("userId", ~$userId) |> Json.export |> function
        | Ok b -> b
        | _ -> assert false
      in
      Reqd.respond_with_string reqd (Response.create `OK) body
  | { Request.meth = `DELETE; _ } ->
      Reqd.respond_with_string reqd (Response.create `OK) "{}"
  | _ -> assert false

let error_handler (_ : Unix.sockaddr) ?request:_ error start_response =
  let open Httpaf in
  let response_body = start_response Headers.empty in
  (match error with
  | `Exn exn ->
      Body.write_string response_body (Printexc.to_string exn);
      Body.write_string response_body "\n"
  | #Status.standard as error ->
      Body.write_string response_body (Status.default_reason_phrase error));
  Body.close_writer response_body

let connection_handler =
  let open Httpaf_lwt_unix in
  Server.create_connection_handler ~request_handler ~error_handler

let listen port =
  let address = Unix.(ADDR_INET (inet_addr_loopback, port)) in
  Lwt_io.establish_server_with_client_socket address connection_handler

let close = Lwt_io.shutdown_server
