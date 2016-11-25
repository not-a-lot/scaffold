xquery version "1.0";
(: ------------------------------------------------------------------
   Coaching application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Generation of formulars from their XML specification files 
   in the file system, the result is stored inside the mesh 
   collection inside the database.

   May 2014 - (c) Copyright 2014 Oppidoc SARL. All Rights Reserved. 
   ------------------------------------------------------------------ :)
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace sg = "http://coaching.ch/ns/supergrid" at "install.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

let $targets := request:get-parameter('gen', '')
let $cmd := request:get-attribute('oppidum.command')
return
  sg:gen-and-save-forms($targets, $cmd/@base-url)
