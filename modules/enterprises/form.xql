xquery version "1.0";
(: --------------------------------------
   Case tracker pilote application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Enterprise search and Enterprise formulars

   December 2014 - (c) Copyright 2014 Oppidoc SARL. All Rights Reserved.
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace _form = "http://oppidoc.com/oppidum/form/app" at "../../app/form.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $goal := request:get-parameter('goal', 'read')
return
  if ($target = 'enterprises') then (: Enterprise search formular :)
    <site:view>
      <site:field Key="enterprises">
        { _form:gen-enterprise-selector($lang, ";multiple=yes;xvalue=EnterpriseRef;typeahead=yes") }
      </site:field>
      <site:field Key="towns">
        { _form:gen-town-selector($lang, ";multiple=yes;xvalue=Town;typeahead=yes") }
      </site:field>
      <site:field Key="countries">
        { form:gen-selector-for('Countries', $lang, ";multiple=yes;xvalue=Country;typeahead=yes") }
      </site:field>
      <site:field Key="sizes">
        { form:gen-selector-for('Sizes', $lang, ";multiple=yes;xvalue=SizeRef;typeahead=yes;select2_minimumResultsForSearch=1") }
      </site:field>
      <site:field Key="domains-of-activities">
        { form:gen-selector-for('DomainActivities', $lang, ";multiple=yes;xvalue=DomainActivityRef;typeahead=yes") }
      </site:field>
      <site:field Key="targeted-markets">
        { form:gen-selector-for('TargetedMarkets', $lang, ";multiple=yes;xvalue=TargetedMarketRef;typeahead=yes") }
      </site:field>
      <site:field Key="persons">
        { _form:gen-person-selector($lang, ";multiple=yes;xvalue=Person;typeahead=yes") }
      </site:field>
    </site:view>
  else (: assumes generic Enterprise formular  :)
    if ($goal = 'read') then
      <site:view>
      </site:view>
    else
      <site:view>
        {
        if ($goal = 'create') then 
          <site:field Key="enterprise">
            { _form:gen-enterprise-selector($lang, ";select2_tags=yes;typeahead=yes") }
          </site:field>
        else
          <site:field Key="enterprise" filter="no">
            <xt:use types="input" param="filter=optional event;class=span a-control;required=true;" label="Name"></xt:use>
          </site:field>
        }
        <site:field Key="country">
          { form:gen-selector-for('Countries', $lang, " optional;multiple=no;typeahead=yes") }
        </site:field>
        <site:field Key="size">
          { form:gen-selector-for('Sizes', $lang, " optional;multiple=no;typeahead=yes;select2_minimumResultsForSearch=1") }
        </site:field>
        <site:field Key="domain-activity">
          { form:gen-selector-for('DomainActivities', $lang, " optional;multiple=no;typeahead=yes") }
        </site:field>
        <site:field Key="targeted-markets">
          { form:gen-selector-for('TargetedMarkets', $lang, " optional;multiple=yes;xvalue=TargetedMarketRef;typeahead=yes") }
        </site:field>
      </site:view>
    
