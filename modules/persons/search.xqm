xquery version "1.0";
(: --------------------------------------
   Case tracker pilote application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Shared database requests for members search

   January 2015 - (c) Copyright 2015 Oppidoc SARL. All Rights Reserved.
   ------------------------------------------------------------------ :)

module namespace search = "http://platinn.ch/coaching/search";

declare namespace httpclient = "http://exist-db.org/xquery/httpclient";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace user = "http://oppidoc.com/ns/user" at "../../lib/user.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

(: ======================================================================
   Generates Person information fields to display in result table
   Includes an Update attribute flag if update is true()
   TODO: include Country fallback to first Case enterprise country for coach
   or to EEN Entity country for KAM/Coord ?
   ======================================================================
:)
declare function search:gen-person-sample ( $person as element(), $country as xs:string?, $role-ref as xs:string?, $lang as xs:string, $update as xs:boolean ) as element() {
  let $e := fn:doc($globals:enterprises-uri)/Enterprises/Enterprise[Id = $person/EnterpriseRef/text()]
  return
    <Person>
      {(
        if ($update) then attribute  { 'Update' } { 'y' } else (),
        $person/(Id | Name | Contacts),
        if ($country) then
          <Country>{ $country }</Country>
        else if ($person/Country) then
          <Country>{ display:gen-name-for('Countries', $person/Country, $lang) }</Country>
        else if ($e/Address/Country) then (: defaults to enterprise's country :)
          <Country>{ display:gen-name-for('Countries', $e/Address/Country, $lang) }</Country>
        else
          (),
        if ($e) then
          <EnterpriseName>{$e/Name/text()}</EnterpriseName>
        else
         ()
        (: extra information to show EEN Entity in case coordinator :)
        (:if ($person/UserProfile/Roles/Role[FunctionRef/text() = $een-coordinator]) then
                  misc:gen_display_name($person/UserProfile/Roles/Role[FunctionRef/text() = $een-coordinator]/RegionalEntityRef, 'RegionalEntityName')
                else
                  ():)
      )}
    </Person>
};

(: ======================================================================
   Generates Person information fields to display in result table
   Includes an Update attribute flag if update is true()
   TODO: include Country fallback to first Case enterprise country for coach
   or to EEN Entity country for KAM/Coord ?
   ======================================================================
:)
declare function search:gen-person-sample ( $person as element(), $role-ref as xs:string?, $lang as xs:string, $update as xs:boolean ) as element() {
  let $e := fn:doc($globals:enterprises-uri)/Enterprises/Enterprise[Id = $person/EnterpriseRef/text()]
  return
    <Person>
      {(
        if ($update) then attribute  { 'Update' } { 'y' } else (),
        $person/(Id | Name | Contacts),
        if ($person/Country) then
          <Country>{ display:gen-name-for('Countries', $person/Country, $lang) }</Country>
        else if ($e/Address/Country) then (: defaults to enterprise's country :)
          <Country>{ display:gen-name-for('Countries', $e/Address/Country, $lang) }</Country>
        else
          (),
        if ($e) then
          <EnterpriseName>{$e/Name/text()}</EnterpriseName>
        else
         ()
        (: extra information to show EEN Entity in case coordinator :)
        (:if ($person/UserProfile/Roles/Role[FunctionRef/text() = $een-coordinator]) then
                  misc:gen_display_name($person/UserProfile/Roles/Role[FunctionRef/text() = $een-coordinator]/RegionalEntityRef, 'RegionalEntityName')
                else
                  ():)
      )}
    </Person>
};

(: ======================================================================
   Returns community member(s) matching request
   FIXME: hard-coded function refs -> user:get-function-ref-for-role('xxx')
   ======================================================================
:)
declare function search:fetch-persons ( $request as element() ) as element()* {
  let $person := $request/Persons/PersonRef/text()
  let $country := $request//Country
  let $function := $request/Functions/FunctionRef/text()
  let $enterprise := $request/Enterprises/EnterpriseRef/text()
  let $region-role-ref := user:get-function-ref-for-role("region-manager")
  let $omni := access:check-user-can('update', 'Person')
  let $uid := if ($omni) then () else user:get-current-person-id()
  return
    <Results>
      <Persons>
        {(
        if ($omni) then attribute { 'Update' } { 'y' } else (),
        if (empty($country)) then
          (: classical search :)
          for $p in fn:doc($globals:persons-uri)/Persons/Person[empty($person) or Id/text() = $person]
          let $id := $p/Id/text()
          where (empty($function) or $p/UserProfile/Roles/Role/FunctionRef = $function)
            and (empty($enterprise) or $p/EnterpriseRef = $enterprise)
          order by $p/Name/LastName
          return
            search:gen-person-sample($p, $region-role-ref, 'en', not($omni) and $uid eq $p/Id/text())
            (: optimization for : not($omni) and access:check-person-update-at-least($uid, $person) :)
        else
          (: optimized search for search by country :)
          let $region-refs :=
            fn:collection($globals:global-info-uri)//Description[@Lang eq 'en']/Selector[@Name = 'RegionalEntities']/Option[Country = $country]/Id/text()
          let $with-country-refs := fn:doc($globals:persons-uri)//Person[Country = $country]/Id[empty($person) or . = $person]
          (: extends to coaches having coached in one of the target country :)
          let $by-coaching-refs := distinct-values(
            fn:collection($globals:cases-uri)//Case[Information/ClientEnterprise/Address/Country = $country]//ResponsibleCoachRef[not(. = $with-country-refs)]
            )
          (: extends to KAM and KAMCO from the target country :)
          let $by-region-refs := distinct-values(
            fn:doc($globals:persons-uri)//Person[.//Role[FunctionRef = ('3', '5')][RegionalEntityRef = $region-refs]]/Id[not(. = $with-country-refs) and not(. = $by-coaching-refs)][empty($person) or Id/text() = $person]
            )
          return (
            for $p in fn:doc($globals:persons-uri)/Persons/Person[Id = $with-country-refs]
            where (empty($function) or $p/UserProfile/Roles/Role/FunctionRef = $function)
              and (empty($enterprise) or $p/EnterpriseRef = $enterprise)
            return
              search:gen-person-sample($p, (), $region-role-ref, 'en', not($omni) and $uid eq $p/Id/text()),
            for $p in fn:doc($globals:persons-uri)/Persons/Person[Id = ($by-coaching-refs)]
            where (empty($person) or $p/Id = $person)
              and (empty($function) or $p/UserProfile/Roles/Role/FunctionRef = $function)
              and (empty($enterprise) or $p/EnterpriseRef = $enterprise)
            return
              search:gen-person-sample($p, 'C', $region-role-ref, 'en', not($omni) and $uid eq $p/Id/text()),
            for $p in fn:doc($globals:persons-uri)/Persons/Person[Id = ($by-region-refs)]
            where (empty($function) or $p/UserProfile/Roles/Role/FunctionRef = $function)
              and (empty($enterprise) or $p/EnterpriseRef = $enterprise)
            return
              search:gen-person-sample($p, 'E', $region-role-ref, 'en', not($omni) and $uid eq $p/Id/text())
            )
        )}
      </Persons>
    </Results>
};

