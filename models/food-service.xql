xquery version "3.0";

declare namespace json="http://www.json.org";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
declare option exist:serialize "method=json media-type=application/json";

let $qId := xs:integer(request:get-parameter('food-category', ()))
let $food := doc('/db/sites/scaffold/ajax-tests/food.xml')/Food
let $category := $food/*[position() = $qId]
  return
    <sample cache="{$qId}">
      {
        for $item at $index in $category/Item
        return
          <items>
            { if ($index = 1) then attribute { 'json:array' } { 'true' } else () }
            <label>{$item/text()}</label>
            <value>{data($item/@value)}</value>
          </items>
      }
    </sample>