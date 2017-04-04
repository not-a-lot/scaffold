xquery version "1.0";
(: --------------------------------------
   Case tracker pilote

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage Enterprise entries inside the database.

   November 2016 - (c) Copyright 2016 Oppidoc SARL. All Rights Reserved.
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace cache = "http://oppidoc.com/ns/cctracker/cache" at "../../lib/cache.xqm";
import module namespace enterprise = "http://oppidoc.fr/ns/ctracker/enterprise" at "enterprise.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Adds a new enterprise record into the database
   FIXME: use a @LastIndex scheme for numbering
   ======================================================================
:)
declare function local:create-enterprise( $cmd as element(), $data as element(), $lang as xs:string ) as element() {
  let $errors := enterprise:validate-enterprise-submission($data, ())
  let $next := request:get-parameter('next', ())
  return
    if (empty($errors)) then
      let $newkey := 
        if (exists(fn:doc($globals:enterprises-uri)/Enterprises/Enterprise/Id)) then
          max(for $key in fn:doc($globals:enterprises-uri)/Enterprises/Enterprise/Id
              return if ($key castable as xs:integer) then number($key) else 0) + 1
        else
          1
      let $result := 
        <Response Status="success">
          <Payload>
            <Name>{$data/Name/text()}</Name>
            <Value>{$newkey}</Value>
          </Payload>
        </Response>
      let $enterprise := enterprise:gen-enterprise-for-writing((), $data, $newkey)
      return (
        misc:create-entity($cmd/@db, 'enterprise', $enterprise),
        cache:invalidate('enterprise', $lang),
        cache:invalidate('town', $lang),
        (: FIXME: invalidate 'beneficiary' in case of creation from a Case ? :)
        if ($next = 'redirect') then
          ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), concat($cmd/@base-url, $cmd/@trail, '?preview=', $newkey))
        else
          ajax:report-success('ACTION-CREATE-SUCCESS', (), $result)
        )
    else
      ajax:report-validation-errors($errors)
};

(: ======================================================================
   Updates an enterprise record into database
   Ajax protocol
   ======================================================================
:)
declare function local:update-enterprise( $ref as xs:string, $data as element(), $lang as xs:string ) as element() {
  let $errors := enterprise:validate-enterprise-submission($data, $ref)
  return
    if (empty($errors)) then
      let $result := 
        <Response Status="success">
          <Payload Table="Enterprise">
            <Name>{$data/Name/text()}</Name>
            <Value>{$ref}</Value>
            { $data/Address/(Town | State) }
            <Size>{ display:gen-name-for('Sizes', $data/SizeRef, $lang) }</Size>
            <DomainActivity>{ display:gen-name-for('DomainActivities', $data/DomainActivityRef, $lang) }</DomainActivity>
            <TargetedMarkets>{ display:gen-name-for('TargetedMarkets', $data/TargetedMarkets/TargetedMarketRef, $lang) }</TargetedMarkets>
          </Payload>
        </Response>
      return 
        if (enterprise:update-enterprise($ref, $data, $lang)) then
          ajax:report-success('ACTION-UPDATE-SUCCESS', (), $result)
        else
          ajax:report-success('ACTION-UPDATE-SAME-SUCCESS', (), $result)
    else
      ajax:report-validation-errors($errors)
  };
  
(: ======================================================================
   Returns the Enterprise with No $ref with a representation depending on $goal
   ======================================================================
:)
declare function local:gen-enterprise( $ref as xs:string, $lang as xs:string, $goal as xs:string ) as element()* {
  let $e := fn:doc(oppidum:path-to-ref())/Enterprises/Enterprise[Id = $ref]
  return
    if (empty($e)) then
      <Enterprise/>
    else if ($goal = 'autofill') then (: Dead or Live Copy generation :)
      let $context := request:get-parameter('context', 'Case')
      let $payload := 
              if ($context = 'Partner') then 
                (
                local:gen-enterprise-reference($e),
                <Address>{ $e/Address/(PostalCode | Town | State | Country) }</Address>
                )
              else
                (
                local:gen-enterprise-reference($e),
                $e/(ShortName | CreationYear),
                misc:unreference($e/(SizeRef | DomainActivityRef)),
                $e/WebSite,
                if ($context = 'Case') then
                  <TargetedMarkets>{
                    if ($e/TargetedMarkets/TargetedMarketRef) then
                      display:gen-name-for('TargetedMarkets', $e/TargetedMarkets/TargetedMarketRef, $lang)
                    else
                      ()
                  }
                  </TargetedMarkets>
                else (: assumes Enteprise in ClientEnterprise in FundingRequest :)
                  <TargetedMarkets _Output="{string-join($e/TargetedMarkets/TargetedMarketRef/text(), " ")}">
                    {
                    display:gen-name-for('TargetedMarkets', $e/TargetedMarkets/TargetedMarketRef, $lang)
                    }
                  </TargetedMarkets>,
                $e/MainActivities,
                $e/Address
                )
      let $envelope := request:get-parameter('envelope', '')
      return
        <data>
          {
          if ($envelope) then
            element { $envelope } { $payload }
          else
            $payload
          }
        </data>
    else if ($goal = 'update') then
      <Enterprise>
        {
        $e/(Name | ShortName | CreationYear | SizeRef | DomainActivityRef | WebSite),
        $e/MainActivities,
        $e/TargetedMarkets,
        $e/Address
        }
      </Enterprise>
    else (: assumes 'read' :)
      <Enterprise>
        {
        $e/(Name | ShortName | CreationYear),
        misc:unreference($e/(SizeRef | DomainActivityRef)),
        $e/WebSite, 
        $e/MainActivities,
        misc:unreference($e/TargetedMarkets),
        misc:unreference($e/Address)
        }
      </Enterprise>
};

(: ======================================================================
   Generates the referencial part of the enterprise for the current request
   This is either the reference to the enterprise alone when invoked from a 'choice' plugin,
   or the reference and the name when invoked from a 'constant' plugin,
   the element names themselves may depend on the invoking context (template)
   ======================================================================
:)
declare function local:gen-enterprise-reference ( $e as element() ) as element()* {
  let $context := request:get-parameter('context', 'Case')
  let $plugin := request:get-parameter('plugin', 'constant')
  return (
    if ($context = 'FundingRequest') then
      $e/Id
    else if ($context = 'Partner') then
      <PartnerRef>{$e/Id/text()}</PartnerRef>
    else (: assumes Case :)
      <EnterpriseRef>{$e/Id/text()}</EnterpriseRef>,
    if ($plugin != 'choice') then
      $e/Name
    else
      ()
    )
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $name := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
return
  if ($m = 'POST') then
    let $data := oppidum:get-data()
    return
      if ($cmd/@action = 'add') then
        if (access:check-user-can('create', 'Enterprise')) then
          local:create-enterprise($cmd, $data, $lang)
        else
          oppidum:throw-error('FORBIDDEN', ())
      else
        if (access:check-user-can('update', 'Enterprise')) then
          local:update-enterprise($name, $data, $lang)
        else
          oppidum:throw-error('FORBIDDEN', ())
  else (: assumes GET :)
    let $goal := request:get-parameter('goal', 'read')
    return
      local:gen-enterprise($name, $lang, $goal)