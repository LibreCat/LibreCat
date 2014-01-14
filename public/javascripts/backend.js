function linkPevz(element){
  var lineId = $(element).attr('id').replace('id_linkPevz_','');
  
  // Someone unchecked the "Link to PEVZ Account" checkbox
  if(!$(element).is(':checked')){
    // So, release input fields and change img back to gray
    $('#auAuthorized' + lineId).attr('src','/images/biNotAuthorized.png');
    $('#id_au_auLuAuthorOId_' + lineId + ', #id_au_auPersonNumber_' + lineId).val("");
    $('#id_au_auGivenName_' + lineId + ', #id_au_auSurname_' + lineId + ', #id_au_auPersonTitle_' + lineId).removeAttr("readonly");
  }
  
  // Someone checked the "Link to PEVZ Account" checkbox
  else{
    var puburl = 'http://pub-dev.ub.uni-bielefeld.de:3000/admin/search_researcher?ftext=';
    var firstName = $('#id_au_auGivenName_' + lineId).val();
    var lastName = $('#id_au_auSurname_' + lineId).val();
    puburl += lastName + ", " + firstName;
  
    $.get(puburl, function(response) {
      var objJSON = eval("(function(){return " + response + ";})()");
      
      // If only one hit... fill out fields and change img to green
      if(objJSON.length == 1){
        var data = objJSON[0];
        var pevzId = "";
        var sbcatId = "";
        var firstName = "";
        var lastName = "";
        var title = "";
      
        $.each(data, function(key, value){
          if(key == "pevzId"){
            pevzId = value;
          }
          if(key == "sbcatId"){
            sbcatId = value;
          }
          if(key == "firstName"){
            firstName = value;
          }
          if(key == "lastName"){
            lastName = value;
          }
          if(key == "title"){
            title = value;
          }
        });
      
        $('#id_au_auLuAuthorOId_' + lineId).val(sbcatId);
        $('#id_au_auPersonNumber_' + lineId).val(pevzId);
        $('#id_au_auGivenName_' + lineId).val(firstName);
        $('#id_au_auSurname_' + lineId).val(lastName);
        if(title != ""){
          $('#id_au_auPersonTitle_' + lineId).val(title);
        }
        $('#id_au_auGivenName_' + lineId + ', #id_au_auSurname_' + lineId + ', #id_au_auPersonTitle_' + lineId).attr("readonly","readonly");
        $('#auAuthorized' + lineId).attr('src','/images/biAuthorized.png');
        $('#id_au_auGivenName_' + lineId + ', #id_au_auSurname_' + lineId).parent().removeClass("has-error");
      
        pevzId = "";
        sbcatId = "";
        firstName = "";
        lastName = "";
        title = "";
      }
      
      // If more than one hit... show modal with choices
      else {        
        var container = $('#linkPevzModal').find('.modal-body').first();
        var table = '<table class="table table-striped" id="lineId' + lineId + '"><tr><th>PEVZ-ID</th><th>Title</th><th>Name</th></tr>';
        
        for(var i=0;i<objJSON.length;i++){
          var data = objJSON[i];
          var pevzId = "";
          var sbcatId = "";
          var firstName = "";
          var lastName = "";
          var title = "";
          $.each(data, function(key, value){
            if(key == "pevzId"){
              pevzId = value;
            }
            if(key == "sbcatId"){
              sbcatId = value;
            }
            if(key == "firstName"){
              firstName = value;
            }
            if(key == "lastName"){
              lastName = value;
            }
            if(key == "title"){
              title = value;
            }
          });
          table += '<tr data-id="' + pevzId + '" data-sbcat="' + sbcatId + '"><td><a href="#" class="pevzLink">' + pevzId + '</a></td><td class="title">' + title + '</td><td class="name" data-firstname="' + firstName + '" data-lastname="' + lastName + '"><a href="#" class="pevzLink">' + firstName + " " + lastName + '</a></td></tr>';
        }
        
        table += "</table>";
        container.append(table);
        
        $('.pevzLink').bind("click", function() {
          var pevzId = $(this).parent().parent().attr('data-id');
          var sbcatId = $(this).parent().parent().attr('data-sbcat');
          var title = $(this).parent().parent().find('.title').text();
          var firstName = $(this).parent().parent().find('.name').attr('data-firstname');
          var lastName = $(this).parent().parent().find('.name').attr('data-lastname');
          
          var lineId = $(this).parents('.table').attr('id').replace('lineId','');
          
          $('#id_au_auPersonNumber_' + lineId).val(pevzId);
          $('#id_au_auGivenName_' + lineId).val(firstName);
          $('#id_au_auSurname_' + lineId).val(lastName);
          if(title != ""){
            $('#id_au_auPersonTitle_' + lineId).val(title);
          }
          $('#id_au_auGivenName_' + lineId + ', #id_au_auSurname_' + lineId + ', #id_au_auPersonTitle_' + lineId).attr("readonly","readonly");
                    
          $('#auAuthorized' + lineId).attr('src','/images/biAuthorized.png');
          $('#id_au_auGivenName_' + lineId + ', #id_au_auSurname_' + lineId).parent().removeClass("has-error");
          $('#linkPevzModal').modal("hide");
          $('#linkPevzModal').find('.modal-body').first().html('');
        });
        
        $('#linkPevzModal').modal("show");
      }
    });
  }
}