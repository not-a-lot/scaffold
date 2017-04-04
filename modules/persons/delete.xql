xquery version "1.0";
(: --------------------------------------
   Case tracker pilote

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Controller to delete a Person.

   March 2014 - (c) Copyright 2014 Oppidoc SARL. All Rights Reserved.
   ----------------------------------------------- :)
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Checks that deleting $person is compatible with current DB state
   Note that Opinions contains direct copy of persons names, hence it is not a dependency
   Note that the person may be attached to an Enterprise (but with a unidirectionnal link)
   WARNING: those rules do not prevent to delete a Person while someone else is performing
   an action that could reference that person (wiki dilemna), however this should be extremely rare
   since usually persons will be added to the database just before beeing referenced inside a case or an activity
   FIXME:
   - check user has no role at all in UserProfile (?)
   ======================================================================
:)
declare function local:validate-person-delete( $id as xs:string, $person as element() ) as element()* {
  let $po := fn:collection($globals:cases-uri)//ProjectOfficerRef[. = $id][1]/ancestor::Case/Information/Acronym/text()
  let $kam := fn:collection($globals:cases-uri)//AccountManagerRef[. = $id][1]/ancestor::Case/Information/Acronym/text()
  let $coach := fn:collection($globals:cases-uri)//ResponsibleCoachRef[. = $id][1]/ancestor::Case/Information/Acronym/text()
  let $ref := for $c in fn:collection($globals:cases-uri)//
                (
                AddresseeRef[. = $id][1] |
                SenderRef[. = $id][1] |
                AssignedByRef[. = $id][1] |
                SentByRef[. = $id][1]
                )
              return $c/ancestor::Case/Information/Acronym/text()
  let $login := if (empty($person/UserProfile/Username)) then () else ajax:throw-error('PERSON-WITH-LOGIN', ())
  return
    let $err0 := if (count($po) > 0) then ajax:throw-error('PERSON-ISA-PO', $po) else ()
    let $err1 := if (count($kam) > 0) then ajax:throw-error('PERSON-ISA-KAM', $kam) else ()
    let $err2 := if (count($coach) > 0) then ajax:throw-error('PERSON-ISA-COACH', $coach) else ()
    let $err3 := if (count($ref) > 0) then ajax:throw-error('PERSON-ISA-REFEREE', $ref[1]) else ()
    let $errors := ($err0, $err1, $err2, $err3, $login)
    return
      if (count($errors) > 0) then
        let $explain :=
          string-join(
            for $e in $errors
            return $e/message/text(), '. ')
        return
          oppidum:throw-error('DELETE-PERSON-FORBIDDEN', (concat($person/Name/FirstName, ' ', $person/Name/LastName), $explain))
      else
        ()
};

(: ======================================================================
   Delete the person targeted by the request
   Do not use this function to delete a person with a login since it will
   not delete the login
   NOTE: currently if the last person is deleted, the next person
   that will be created will get the same Id since we do not memorize a LastIndex
   ======================================================================
:)
declare function local:delete-person( $person as element() ) as element()* {
  (: copy id and name to a new string to avoid loosing once deleted :)
  let $result :=
    <Response Status="success">
      <Payload Table="Person">
        <Value>{string($person/Id)}</Value>
      </Payload>
    </Response>
  let $name := concat($person/Name/FirstName, ' ', $person/Name/LastName)
  return (
    update delete $person,
    ajax:report-success('DELETE-PERSON-SUCCESS', $name, $result)
    )
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $person-uri := oppidum:path-to-ref()
let $id := tokenize($cmd/@trail,'/')[2]
let $person := fn:doc($person-uri)/Persons/Person[Id = $id]
(:let $lang := string($cmd/@lang):)
return
  if ($person) then (: sanity check :)
    if (access:check-user-can('delete', 'Person', $person)) then (: 1st check : authorized user ? :)
      let $errors := local:validate-person-delete($id, $person)  (: 2nd: compatible database state ? :)
      return
        if (empty($errors)) then
          if ($m = 'DELETE' or (($m = 'POST') and (request:get-parameter('_delete', ()) eq "1"))) then (: real delete  :)
            local:delete-person($person)
          else if ($m = 'POST') then (: delete pre-step - we use POST to avoid forgery - :)
            ajax:report-success('DELETE-PERSON-CONFIRM', concat($person/Name/FirstName, ' ', $person/Name/LastName))
          else
            ajax:throw-error('URI-NOT-SUPPORTED', ())
        else
          $errors
    else
      ajax:throw-error('FORBIDDEN', ())
  else
    ajax:throw-error('URI-NOT-SUPPORTED', ())

