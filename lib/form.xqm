xquery version "1.0";
(: --------------------------------------
   Oppidoc Business Application Development Framework

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Functions to generate extension points for the application formulars.
   Each function has to localize its results in the current language.

   See also :
   -'select2' documentation at http://ssire.github.io/axel-forms/editor/editor.xhtml#filters/Select2

   November 2016 - (c) Copyright 2016 Oppidoc SARL. All Rights Reserved.
   ----------------------------------------------- :)

module namespace form = "http://oppidoc.com/oppidum/form";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "display.xqm";
import module namespace cache = "http://oppidoc.com/ns/cctracker/cache" at "cache.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";

declare option exist:serialize "method=xml media-type=text/xml";

declare function form:setup-select2 ( $params as xs:string ) as xs:string {
  if (ends-with($params,"px")) then
    (: assumes it contains a custom width like in stage-search :)
    concat("select2_dropdownAutoWidth=true;class=a-control;filter=select2", $params)
  else
    concat("select2_dropdownAutoWidth=true;select2_width=off;class=span12 a-control;filter=select2", $params)
};

(: ======================================================================
   Generates fake field for fields not yet available
   ======================================================================
:)
declare function form:gen-unfinished-selector ( $lang as xs:string, $params as xs:string ) as element() {
  <xt:use types="choice"
    param="class=span12 a-control;{$params}"
    values="1 2 3 4 5"
    i18n="Un Deux Trois Quatre Cinq"
    />
};

(: ======================================================================
   Generates XTiger XML 'choice' element for a given selector as a radio button box
   TODO:
   - caching
   ======================================================================
:)
declare function form:gen-radio-selector-for( $name as xs:string, $lang as xs:string, $noedit as xs:boolean, $class as xs:string ) as element()* {
  let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $concat := if (starts-with($defs/@Label, 'V+')) then true() else false()
  let $label := if ($concat) then substring-after($defs/@Label, 'V+') else string($defs/@Label)
  return
     let $pairs :=
        for $p in $defs//Option
        let $v := $p/*[local-name(.) eq string($defs/@Value)]/text()
        let $l := if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/*[local-name(.) eq $label]
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
        return 
          if ($noedit) then
            <xt:use types="choice" param="appearance=full;multiple=no;class={$class} readonly;noedit=true" values="{$ids}" i18n="{$names}"/>
          else
            <xt:use types="choice" param="filter=optional;appearance=full;multiple=no;class={$class}" values="{$ids}" i18n="{$names}"/>
};

declare function form:gen-radio-selector-for( $name as xs:string, $lang as xs:string, $noedit as xs:boolean ) as element()* {
  form:gen-radio-selector-for($name, $lang, $noedit, 'a-select-box')
};

(: ======================================================================
   Generates XTiger XML 'choice' element for a given selector as a drop down list
   TODO:
   - caching
   ======================================================================
:)
declare function form:gen-selector-for ( $name as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $concat := if (starts-with($defs/@Label, 'V+')) then true() else false()
  let $label := if ($concat) then substring-after($defs/@Label, 'V+') else string($defs/@Label)
  return
     let $pairs :=
        for $p in $defs//Option
        let $v := $p/*[local-name(.) eq string($defs/@Value)]/text()
        let $l := if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/*[local-name(.) eq $label]
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
      return
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Same as above but uses an explicit label to identify the selector's label
   ======================================================================
:)declare function form:gen-selector-for ( $name as xs:string, $lang as xs:string, $params as xs:string, $label as xs:string ) as element() {
  let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
  return
     let $pairs :=
        for $p in $defs//Option
        let $v := $p/*[local-name(.) eq string($defs/@Value)]/text()
        let $l := $p/*[local-name(.) eq $label]
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
      return
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates a 'choice2' selector with JSON menu definition
   Notes : only applies to two level selection (NOGA and Markets)
   TODO: cache
   ======================================================================
:)
declare function form:gen-json-selector-for ( $name as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $json := 
    <json>
      {
      for $g in fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]/Group
      return
        element { concat('_', $g/Code/text()) }
        {(
        element { '__label' } { $g/Name/text() },
        for $o in $g//Option
        return
          element { concat('_', $o/Code/text()) } {
            $o/Name/text()
          }
        )}
      }
    </json>
  let $res := util:serialize($json, 'method=json')
  (: trick because of JSON serialization bug, assumes at list 10 chars :)
  (:let $dedouble := concat(substring-before($res, concat("}", substring($res, 1, 10))), "}"):)
  let $filter := replace($res, '"_', '"')
  return
   <xt:use types='choice2' param="{$params}" values='{ $filter }'/>
};

(: ======================================================================
   Returns the language independent selector, this is the selector 
   definition used to encode non linguistic meta-data
   ====================================================================== 
:)
declare function form:get-normative-selector-for( $name as xs:string ) as element()? {
  fn:collection($globals:global-info-uri)//Description[@Role = 'normative']/Selector[@Name eq $name]
};
