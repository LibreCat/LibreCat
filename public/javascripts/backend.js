function linkPevz(element){
	var lineId = $(element).attr('id').replace('id_linkPevz_','');
	
	// Someone unchecked the "Link to PEVZ Account" checkbox
	if(!$(element).is(':checked')){
		// So, release input fields and change img back to gray
		$('#auAuthorized' + lineId).attr('src','/images/biNotAuthorized.png');
		$('#id_' + lineId).val("");
		$('#first_name_' + lineId + ', #last_name_' + lineId).removeAttr("readonly");
		var orig_first_name = "";
		orig_first_name = $('#orig_first_name_' + lineId).val();
		var orig_last_name = "";
		orig_last_name = $('#orig_last_name_' + lineId).val();
		$('#first_name_' + lineId).val(orig_first_name);
		$('#orig_first_name_' + lineId).val("");
		$('#last_name_' + lineId).val(orig_last_name);
		$('#orig_last_name_' + lineId).val("");
	}
	
	// Someone checked the "Link to PEVZ Account" checkbox
	else{
		var puburl = 'http://pub-dev.ub.uni-bielefeld.de:3000/myPUB/search_researcher?ftext=';
		var narrowurl = puburl;
		var first_name = $('#first_name_' + lineId).val();
		$('#orig_first_name_' + lineId).val(first_name);
		var firstname = first_name.toLowerCase();
		var last_name = $('#last_name_' + lineId).val();
		$('#orig_last_name_' + lineId).val(last_name);
		var lastname = last_name.toLowerCase();
		if(firstname){
			narrowurl += "firstname=" + firstname + "*";
		}
		if(firstname && lastname){
			narrowurl += " AND ";
		}
		if(lastname){
			narrowurl += "lastname=*" + lastname + "*";
		}
		
		$.get(narrowurl, function(response) {
			var objJSON = eval("(function(){return " + response + ";})()");

			// If only one hit... fill out fields and change img to green
			if(objJSON.length == 1){
				var data = objJSON[0];
				var pevzId = "";
				var first_name = "";
				var last_name = "";
				
				$.each(data, function(key, value){
					if(key == "_id"){
						pevzId = value;
					}
					if(key == "first_name"){
						first_name = value;
					}
					if(key == "last_name"){
						last_name = value;
					}
				});
				
				//$('#id_' + lineId).val(pevzId);
				$('#first_name_' + lineId).val(first_name);
				$('#last_name_' + lineId).val(last_name);
				$('#first_name_' + lineId + ', #last_name_' + lineId).attr("readonly","readonly");
				$('#auAuthorized' + lineId).attr('src','/images/biAuthorized.png');
				$('#first_name_' + lineId + ', #last_name_' + lineId).parent().removeClass("has-error");
				
				if($('#author_json_' + lineId).length){
					$('#author_json_' + lineId).val("");
					$('#author_json_' + lineId).val('{"last_name":"' + last_name + '", "first_name":"' + first_name + '", "full_name":"' + last_name + ', ' + first_name + '", "id":"' + pevzId + '"}');
				}
				if($('#editor_json_' + lineId).length){
					$('#editor_json_' + lineId).val("");
					$('#editor_json_' + lineId).val('{"last_name":"' + last_name + '", "first_name":"' + first_name + '", "full_name":"' + last_name + ', ' + first_name + '", "id":"' + pevzId + '"}');
				}
				if($('#translator_json_' + lineId).length){
					$('#translator_json_' + lineId).val("");
					$('#translator_json_' + lineId).val('{"last_name":"' + last_name + '", "first_name":"' + first_name + '", "full_name":"' + last_name + ', ' + first_name + '", "id":"' + pevzId + '"}');
				}
				
				pevzId = "";
				first_name = "";
				last_name = "";
			}
			
			// If more than one hit... show modal with choices
			else if(objJSON.length > 1){
				var container = $('#linkPevzModal').find('.modal-body').first();
				container.html('');
				var table = '<p><strong>Exact hits:</strong></p><table class="table table-striped" id="lineId' + lineId + '"><tr><th>PEVZ-ID</th><th>Name</th></tr>';
				var rows = "";
				var table2 = '<p><strong>Further hits:</strong></p><table class="table table-striped" id="lineId' + lineId + '"><tr><th>PEVZ-ID</th><th>Name</th></tr>';
				var rows2 = "";
				
				for(var i=0;i<objJSON.length;i++){
					var data = objJSON[i];
					var pevzId = "";
					var first_name = "";
					var last_name = "";
					$.each(data, function(key, value){
						if(key == "_id"){
							pevzId = value;
						}
						if(key == "first_name"){
							first_name = value;
							first_nameLc = value.toLowerCase();
						}
						if(key == "last_name"){
							last_name = value;
							last_nameLc = value.toLowerCase();
						}
					});
					
					if((firstname == first_name.toLowerCase() && lastname == "") || (lastname == last_name.toLowerCase() && firstname == "") || (lastname == last_name.toLowerCase() && firstname == first_name.toLowerCase())){
						rows += '<tr data-id="' + pevzId + '"><td><a href="#" class="pevzLink">' + pevzId + '</a></td><td class="name" data-firstname="' + first_name + '" data-lastname="' + last_name + '"><a href="#" class="pevzLink">' + first_name + " " + last_name + '</a></td></tr>';
					}
					else {
						rows2 += '<tr data-id="' + pevzId + '"><td><a href="#" class="pevzLink">' + pevzId + '</a></td><td class="name" data-firstname="' + first_name + '" data-lastname="' + last_name + '"><a href="#" class="pevzLink">' + first_name + " " + last_name + '</a></td></tr>';
					}
					
				}
				
				if(rows == ""){
					table = "<p><strong>Exact hits:</strong></p><p>There were no exact hits for <em>'" + firstname + " " + lastname + "'</em>.</p>";
				}
				else{
					table += rows + "</table>";
				}
				
				if(rows2 == ""){
					table2 = "";
				}
				else {
					table2 += rows2 + "</table>";
				}

				container.append(table);
				container.append(table2);
				
				$('.pevzLink').bind("click", function() {
					var pevzId = $(this).parent().parent().attr('data-id');
					var first_name = $(this).parent().parent().find('.name').attr('data-firstname');
					var last_name = $(this).parent().parent().find('.name').attr('data-lastname');
					
					var lineId = $(this).parents('.table').attr('id').replace('lineId','');
					
					$('#first_name_' + lineId).val(first_name);
					$('#last_name_' + lineId).val(last_name);
					$('#first_name_' + lineId + ', #last_name_' + lineId).attr("readonly","readonly");
					
					$('#auAuthorized' + lineId).attr('src','/images/biAuthorized.png');
					$('#first_name_' + lineId + ', #last_name_' + lineId).parent().removeClass("has-error");
					$('#linkPevzModal').modal("hide");
					$('#linkPevzModal').find('.modal-body').first().html('');
					
					if($('#author_json_' + lineId).length){
						$('#author_json_' + lineId).val("");
						$('#author_json_' + lineId).val('{"last_name":"' + last_name + '", "first_name":"' + first_name + '", "full_name":"' + last_name + ', ' + first_name + '", "id":"' + pevzId + '"}');
					}
					if($('#editor_json_' + lineId).length){
						$('#editor_json_' + lineId).val("");
						$('#editor_json_' + lineId).val('{"last_name":"' + last_name + '", "first_name":"' + first_name + '", "full_name":"' + last_name + ', ' + first_name + '", "id":"' + pevzId + '"}');
					}
					if($('#translator_json_' + lineId).length){
						$('#translator_json_' + lineId).val("");
						$('#translator_json_' + lineId).val('{"last_name":"' + last_name + '", "first_name":"' + first_name + '", "full_name":"' + last_name + ', ' + first_name + '", "id":"' + pevzId + '"}');
					}
				});

				$('#linkPevzModal').modal("show");
			}
			
			// No results found
			else {
				var container = $('#linkPevzModal').find('.modal-body').first();
				container.html('');
				container.append('<p class="has-error">No results found.</p>');
				$('#linkPevzModal').modal("show");
			}
		});
	}
}

function editAuthorIds(direction){
	if(direction == "edit"){
		$('.authorIds').css('display','none');
		$('.authorIds_input').attr('style','display:display');
	}
	else if(direction == "cancel"){
		$('.authorIds').attr('style','display:display');
		$('.authorIds_input').attr('style','display:none');
	}
}