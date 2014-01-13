function auSelToggle(id, obj) {
   sbutton = 'auSel' + id;
   var ele = document.getElementById(sbutton);

     var tform = document.forms['reLoad'];

   auth = 'auAuthorized' + id;
      
   if (obj.checked) {
     if (eval("tform.au_auLuAuthorOId_" + id + ".value") == "") {
       ele.style.visibility = "visible";
     } else {
       ele.style.visibility = "hidden";
     }
   } else {
     ele.style.visibility = "hidden";
     auId = 'au_auLuAuthorOId_' + id;
     var ele3 = document.getElementById(auth);
     ele3.src = "/images/biNotAuthorized.png";
     var ele2 = eval ("self.document.reLoad." + auId);
     ele2.value = '';
 
     eval("tform.au_auSurname_" + id + ".readOnly = false");
     eval("tform.au_auGivenName_" + id + ".readOnly = false");
     eval("tform.au_auPersonTitle_" + id + ".readOnly = false");
     eval("tform.au_auLuAuthorOId_" + id + ".value = ''");
   }

   return true;
}

function selectAuthor(surname, givenName, fieldNr) {
	openWdw('http://pub-dev.ub.uni-bielefeld.de/authority_author?func=selectAuthor&searchSurname=' + surname.value + '&searchGivenNames=' + givenName.value + '&openerForm=reLoad&authorFieldNumber=' + fieldNr,'500','800','650','30','selectAuthor');              
}