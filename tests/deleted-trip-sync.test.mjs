import assert from "node:assert/strict";
import fs from "node:fs";

const source=fs.readFileSync(new URL("../index.html",import.meta.url),"utf8");

function extractFunction(name){
  const start=source.indexOf(`function ${name}(`);
  assert.notEqual(start,-1,`${name} must exist`);
  const lineEnd=source.indexOf("\n",start);
  const singleLine=source.slice(start,lineEnd<0?source.length:lineEnd);
  if(singleLine.trimEnd().endsWith("}"))return singleLine;
  const bodyStart=source.indexOf("{",start);
  let depth=0;
  for(let index=bodyStart;index<source.length;index+=1){
    if(source[index]==="{")depth+=1;
    else if(source[index]==="}"&&--depth===0)return source.slice(start,index+1);
  }
  throw new Error(`Could not parse ${name}`);
}

const names=["normalizedDeletedIds","withoutDeletedItems","mergeItems","mergeChecklistGroups","mergeDeletedSyncItems","mergeCloudData"];
const factory=new Function("hasStoredValue","EXCHANGE_SETTINGS_KEY","HIDDEN_DEFAULT_TRIPS_KEY","HOME_LAYOUT_KEY","HOME_QUICK_TOOLS_KEY","CURRENT_TRIP_KEY","BUDGET_SELECTED_TRIP_KEY","CURRENCY_HOLDINGS_KEY","HOLDINGS_KEY","BUDGET_KEY",`${names.map(extractFunction).join("\n")};return{mergeCloudData};`);
const {mergeCloudData}=factory(()=>false,"exchange","hidden","layout","tools","current","budgetTrip","currencyHoldings","holdings","budget");

const trip={id:"custom-disposable-busan",title:"Disposable Busan",eventStart:"2027-01-01"};
const merged=mergeCloudData(
  {checklists:{settings:{},customTrips:[trip],tripEngine:{[trip.id]:{events:[{id:"event-1"}]}}}},
  {checklists:{settings:{deletedCustomTrips:[trip.id],deletedItems:{}},customTrips:[],tripEngine:{}}}
);
assert.deepEqual(merged.checklists.customTrips,[]);
assert.equal(merged.checklists.tripEngine[trip.id],undefined);
assert.deepEqual(merged.checklists.settings.deletedCustomTrips,[trip.id]);
const sameNameDifferentId={...trip,id:"custom-other-account"};
const isolated=mergeCloudData(
  {checklists:{settings:{},customTrips:[sameNameDifferentId]}},
  {checklists:{settings:{deletedCustomTrips:[trip.id]},customTrips:[]}}
);
assert.deepEqual(isolated.checklists.customTrips,[sameNameDifferentId]);

const mergedLists=mergeCloudData(
  {checklists:{settings:{},personalItineraries:[{id:"it-1"}],personalStays:[{id:"stay-1"}],pastFestivalRecords:[{id:"past-1"}],checklistTemplates:[{id:"tpl-1"}]}},
  {checklists:{settings:{deletedItems:{personalItineraries:["it-1"],personalStays:["stay-1"],pastFestivalRecords:["past-1"],checklistTemplates:["tpl-1"]}}}}
);
assert.deepEqual(mergedLists.checklists.personalItineraries,[]);
assert.deepEqual(mergedLists.checklists.personalStays,[]);
assert.deepEqual(mergedLists.checklists.pastFestivalRecords,[]);
assert.deepEqual(mergedLists.checklists.checklistTemplates,[]);

const checklist=mergeCloudData(
  {checklists:{settings:{},deletedChecklistItems:{fuji:["packing-1"]},tripEngine:{fuji:{checklist:[{id:"essential",items:[{id:"packing-1"},{id:"packing-2"}]}]}}}},
  {checklists:{settings:{},tripEngine:{fuji:{}}}}
);
assert.deepEqual(checklist.checklists.tripEngine.fuji.checklist[0].items,[{id:"packing-2"}]);

const defaults=mergeCloudData(
  {checklists:{settings:{hiddenDefaultTrips:["fuji"]}}},
  {checklists:{settings:{hiddenDefaultTrips:["fuji"]}}}
);
assert.deepEqual(defaults.checklists.settings.hiddenDefaultTrips,["fuji"]);

console.log("deleted-trip-sync tests: PASS");
