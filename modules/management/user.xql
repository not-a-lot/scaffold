xquery version "1.0";
(: --------------------------------------
   Case tracker pilote application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   User account management

   March 2014 - (c) Copyright 2014 Oppidoc SARL. All Rights Reserved. 
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns the list of user with their account information
   ======================================================================
:)
declare function local:gen-users-for-viewing() as element()* {
  <Persons>
  {
  for $p in fn:doc($globals:persons-uri)/Persons/Person
  let $login := $p//Username
  order by lower-case($p/Name/LastName), $p/Name/FirstName
  return
    <Person>
      {
      if ($login/text() and xdb:exists-user($login/text())) then
        attribute { 'Login' } { '1' }
      else 
        (),
      $p/(Id | Name | Contacts/Email | Country),
      <Roles>{ display:gen-roles-for($p/UserProfile/Roles, 'en') }</Roles>,
      if ($login/text()) then $login else ()
      }
    </Person>
  }
  </Persons>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $name := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
return
  if ($m = 'POST') then
    let $data := oppidum:get-data()
    return
      ()
  else (: assumes GET :)
    local:gen-users-for-viewing()