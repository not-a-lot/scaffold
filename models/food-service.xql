xquery version "3.0";

module namespace food-service = "food-service.xql";
declare namespace json="http://www.json.org";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
declare option exist:serialize "method=json media-type=application/json";

let $qId := request:get-parameter('food-category', ())
(:let $qId := 1 :)(: $queryTerm := 'Fruit' :)
let $food := doc('/db/sites/scaffold/ajax-tests/food.xml')/Food
let $category := $food/*[position() = $qId] (: $food/*[name() = $queryTerm] :)

return
  <sample cache="{$qId}">
    <items>
    { attribute { 'json:array' } { 'true' } }
    {
      for $item in $category/Item
      return (
        <label>{$item/text()}</label>,
        <value>{data($item/@value)}</value>
      )
    }
    </items>
  </sample>