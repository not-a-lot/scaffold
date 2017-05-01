xquery version "3.0";

declare namespace json="http://www.json.org";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
declare option exist:serialize "method=json media-type=application/json";

let $qTerm := request:get-parameter('q', ())
let $e := doc('/db/sites/scaffold/enterprises/enterprises.xml')/Enterprises
return
  if ($qTerm eq '') then () (: TODO :)
  else
    let $matches := $e/Enterprise[matches(Name, $qTerm, "i")]
    return
      if (count($matches) eq 0)
      then
        () (: TODO :)
      else
        <data>
          <items json:array="true"> {
            for $item in $matches
            return
              (<id>{$item/Id/text()}</id>,
              <text>{$item/Name/text()}</text>)
          }
          </items>
          <!-- TODO : what about the 'more' key-value ? -->
        </data>