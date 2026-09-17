// Only the DOM operations used by collection/validation/event handlers.
var questions = [], ranges = [];
function control(value) {
  var attrs = {};
  return {value:value, events:{},
    getAttribute:function(k){return attrs[k] || null;},
    setAttribute:function(k,v){attrs[k]=v;},
    addEventListener:function(k,f){this.events[k]=f;},
    parentElement:{querySelector:function(){return {textContent:''};}}};
}
function question(id, kind, required, input, parent) {
  return {
    getAttribute:function(k){return {'data-id':id,'data-tipo':kind,
      'data-required':required?'1':null, 'data-condicional':parent?'1':null}[k] || null;},
    querySelector:function(s){return s === 'input[type="radio"]:checked' ? null : input || null;},
    querySelectorAll:function(){return [];},
    scrollIntoView:function(){},
    parentElement:{closest:function(){return parent || null;}}
  };
}
function button(p) {
  return {closest:function(){return p;},
    parentElement:{querySelector:function(){return {
      classList:{toggle:function(){}},setAttribute:function(){}};}}};
}
var form = {innerHTML:'',querySelectorAll:function(){return ranges;}};
var document = {
  getElementById:function(id){return id === 'form-anamnese' ? form : null;},
  querySelectorAll:function(s){
    if(s === '.pergunta[data-condicional="1"]')
      return questions.filter(function(p){return p.getAttribute('data-condicional') === '1';});
    if(s === '.pergunta:not([data-condicional="1"])')
      return questions.filter(function(p){return p.getAttribute('data-condicional') !== '1';});
    return questions;
  }
};
