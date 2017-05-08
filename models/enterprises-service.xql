xquery version "3.0";

declare namespace json="http://www.json.org";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
declare option exist:serialize "method=json media-type=application/json";

let $qTerm := request:get-parameter('q', ())
return
  if($qTerm eq ()) then <data></data> else (: This test doesn't seem to work. This causes an error 500,
  although it doesn't make the client-side freeze. But actually, select2 probably shouldn't
  send an empty request when we just click on the drop-down list. At least, in the demo on Select2's website, it doesn't :)
let $e := doc('/db/sites/scaffold/enterprises/enterprises.xml')/Enterprises
return
    let $matches := $e/Enterprise[matches(Name, $qTerm, "i")]
    let $count := count($matches)
    return
      <data>
        <total_count>{$count}</total_count>
        <!-- can't find the right syntax to obtain integers and booleans in the json response. Tried :
        false, {false()}, [false], json:literal=false, {xs:boolean(false())}... are always parsed as strings -->
        <!-- NB : it should also be possible to parse the response in JavaScript, in the processResults method
        inside the select2 AXEL-FORMS plugin. But we want to spare the users having to modify the JavaScript -->
        <incomplete_results>{false()}</incomplete_results> {
          if ($count eq 0) then
            <items json:array="true"></items>
          else for $item in $matches
          return
          <items json:array="true"> <!-- <items> must be inside the for even though we don't want to repeat it -->
            <id>{$item/Id/text()}</id>
            <text>{$item/Name/text()}</text>
          </items>
        }
        <!-- TODO : what about the 'more' key-value (seems obsolete, replaced by pagination) ? -->
        <!-- This pagination mechanism allows Select2 not to display all the results in one block, but to ask the
        server for more once the user has a scrolled down the list enough. But this requires a stateful service.
        This is independent from the incremental search mechanism that occurs gradually while the user types into
        the search field. -->
        <!-- If <items> is outside the for loop :
        returns : { "items" : [{ "id" : ["207", "675", "1062", "1573", "1892", "2456"], "text" : ["Secure Secure Ltd", "ONTECH SECURITY S.L.", "Dyadic Security Ltd.", "APPLIED SECURITY GMBH", "Secon Solutions Limited", "InnoSec Ltd"] }] }
        should return : { "items" : [{ "id" : "207", "text" : "Secure Secure Ltd" }, { "id" : "675", "text" : "ONTECH SECURITY S.L." }, ... { "id" : ..., "text" : ... }, ...]} -->
      </data>