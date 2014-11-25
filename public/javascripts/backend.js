/**
 * 
 * myPUB main/search page
 * 
 */


/**
 * Display/hide edit form for author IDs
 * 
 * @param direction = [edit|cancel] display or hide form
 */
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

/**
 * Generates and displays link for request_a_copy
 * @param file_id
 * @param pub_id
 */
function generate_link(file_id, pub_id){
	var url = '/requestcopy/' + pub_id + '/' + file_id;
	$.post(url, {approved:1}, function(response) {
		var request_url = response;
		$("ul[id$='_rac_dd_" + file_id + "'] li input").val(request_url);
		$('ul[id$="_rac_dd_' + file_id + '"]').dropdown('toggle');
	});
}


/**
 * 
 * Publication Edit Form
 * 
 */


/**
 * Section Basic Fields
 */

/**
 * Link author name to PEVZ account
 */
function linkPevz(element){
	var type = "";
	type = $(element).attr('data-type');
	var lineId = $(element).attr('id').replace(type + 'link_pevz_','');
	
	// Someone unchecked the "Link to PEVZ Account" checkbox
	if($('#' + type + 'Authorized' + lineId).attr('alt') == "Not Authorized"){
		var puburl = '/myPUB/search_researcher?ftext=';
		var narrowurl = "";
		var longurl = "";
		var first_name = $('#' + type + 'first_name_' + lineId).val();
		$('#' + type + 'orig_first_name_' + lineId).val(first_name);
		var firstname = first_name.toLowerCase();
		var last_name = $('#' + type + 'last_name_' + lineId).val();
		$('#' + type + 'orig_last_name_' + lineId).val(last_name);
		var lastname = last_name.toLowerCase();
		if(firstname){
			// if name consists of more than one word, use any and ""
			if(firstname.indexOf(" ") > -1){
				narrowurl += '(firstname any "' + firstname + '"';
				longurl += '(oldfirstname any "' + firstname + '"';
			}
			// if name contains [-äöüß], truncating won't work, so use literal search
			else if(firstname.indexOf("-") > -1 || firstname.indexOf("\u00E4") > -1 || firstname.indexOf("\u00F6") > -1 || firstname.indexOf("\u00FC")> -1 || firstname.indexOf("\u00DF") > -1){
				narrowurl += "firstname=" + firstname;
				longurl += "oldfirstname=" + firstname;
			}
			else {
				narrowurl += "firstname=" + firstname + "*";
				longurl += "oldfirstname=" + firstname + "*";
			}
		}
		if(firstname && lastname){
			narrowurl += " AND ";
			longurl += " AND ";
		}
		if(lastname){
			// if name consists of more than one word, use any and ''
			if(lastname.indexOf(" ") > -1){
				narrowurl += 'lastname any "' + lastname + '"';
				longurl += 'oldlastname any "' + lastname + '"';
			}
			// if name contains [-äöüß], truncating won't work, so use literal search
			else if(lastname.indexOf("-") > -1 || lastname.indexOf("\u00E4") > -1 || lastname.indexOf("\u00F6") > -1 || lastname.indexOf("\u00FC") > -1 || lastname.indexOf("\u00DF") > -1){
				narrowurl += "lastname=" + lastname;
				longurl += "oldlastname=" + lastname;
			}
			else{
				narrowurl += "lastname=*" + lastname + "*";
				longurl += "oldlastname=*" + lastname + "*";
			}
		}
		if(narrowurl != "" && longurl != ""){
			narrowurl = puburl + "(" + narrowurl + ")" + " OR " + "(" + longurl + ")";
		}
		else if(narrowurl != "" && longurl == ""){
			narrowurl = puburl + narrowurl;
		}
		else if(narrowurl == "" && longurl != ""){
			narrowurl = puburl + longurl;
		}
		
		$.get(narrowurl, function(response) {
			var objJSON = eval("(function(){return " + response + ";})()");

			// If only one hit... fill out fields and change img to green
			if(objJSON.length == 1 && (!objJSON[0].old_full_name || !objJSON[0].full_name)){
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
				
				$('#' + type + 'first_name_' + lineId).val(first_name);
				$('#' + type + 'last_name_' + lineId).val(last_name);
				$('#' + type + 'full_name_' + lineId).val(last_name + ", " + first_name);
				$('#' + type + 'id_' + lineId).val(pevzId);
				$('#' + type + 'first_name_' + lineId + ', #' + type + 'last_name_' + lineId).attr("readonly","readonly");
				$('#' + type + 'Authorized' + lineId).attr('src','/images/biAuthorized.png');
				$('#' + type + 'Authorized' + lineId).attr('alt','Authorized');
				$('#' + type + 'first_name_' + lineId + ', #' + type + 'last_name_' + lineId).parent().removeClass("has-error");
				
				pevzId = "";
				first_name = "";
				last_name = "";
			}
			
			// If more than one hit... show modal with choices
			else if(objJSON.length > 1 || (objJSON.length == 1 && objJSON[0].old_full_name && objJSON[0].full_name)){
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
					var old_first_name = "";
					var last_name = "";
					var old_last_name = "";
					$.each(data, function(key, value){
						if(key == "_id"){
							pevzId = value;
						}
						if(key == "first_name"){
							first_name = value;
							first_nameLc = value.toLowerCase();
						}
						if(key == "old_first_name"){
							old_first_name = value;
							old_first_nameLc = value.toLowerCase();
						}
						if(key == "last_name"){
							last_name = value;
							last_nameLc = value.toLowerCase();
						}
						if(key == "old_last_name"){
							old_last_name = value;
							old_last_nameLc = value.toLowerCase();
						}
					});
					
					if((firstname == first_name.toLowerCase() && lastname == "") || (lastname == last_name.toLowerCase() && firstname == "") || (lastname == last_name.toLowerCase() && firstname == first_name.toLowerCase()) || (firstname == old_first_name.toLowerCase() && lastname == "") || (lastname == old_last_name.toLowerCase() && firstname == "") || (lastname == old_last_name.toLowerCase() && firstname == old_first_name.toLowerCase())){
						rows += '<tr data-id="' + pevzId + '"><td><a href="#" class="pevzLink">' + pevzId + '</a></td><td class="name" data-firstname="' + first_name + '" data-lastname="' + last_name + '"><a href="#" class="pevzLink">' + first_name + " " + last_name + '</a></td></tr>';
						if(old_first_name || old_last_name){
							rows += '<tr data-id="' + pevzId + '"><td><a href="#" class="pevzLink">' + pevzId + '</a></td><td class="name" data-firstname="' + old_first_name + '" data-lastname="' + old_last_name + '"><a href="#" class="pevzLink">' + old_first_name + " " + old_last_name + '</a> (now ' + first_name + ' ' + last_name + ')</td></tr>';
						}
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
					
					$('#' + type + 'first_name_' + lineId).val("");
					$('#' + type + 'first_name_' + lineId).val(first_name);
					$('#' + type + 'last_name_' + lineId).val("");
					$('#' + type + 'last_name_' + lineId).val(last_name);
					$('#' + type + 'full_name_' + lineId).val(last_name + ", " + first_name);
					$('#' + type + 'first_name_' + lineId + ', #' + type + 'last_name_' + lineId).attr("readonly","readonly");
					$('#' + type + 'id_' + lineId).val(pevzId);
					
					$('#' + type + 'Authorized' + lineId).attr('src','/images/biAuthorized.png');
					$('#' + type + 'Authorized' + lineId).attr('alt','Authorized');
					$('#' + type + 'first_name_' + lineId + ', #' + type + 'last_name_' + lineId).parent().removeClass("has-error");
					$('#linkPevzModal').modal("hide");
					$('#linkPevzModal').find('.modal-body').first().html('');
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


/**
 * Revert to original input after un-checking Link to PEVZ Account
 */
function revert_name(element){
	var type = "";
	type = $(element).attr('data-type');
	var lineId = $(element).attr('id').replace(type + 'revert_','');
	var orig_first_name = "";
	orig_first_name = $('#' + type + 'orig_first_name_' + lineId).val();
	var orig_last_name = "";
	orig_last_name = $('#' + type + 'orig_last_name_' + lineId).val();
	
	if($('#' + type + 'Authorized' + lineId).attr('alt') == "Authorized"){
		// Uncheck, release input fields and change img back to gray
		$('#' + type + 'Authorized' + lineId).attr('src','/images/biNotAuthorized.png');
		$('#' + type + 'Authorized' + lineId).attr('alt','Not Authorized');
		$('#' + type + 'id_' + lineId).val("");
		$('#' + type + 'first_name_' + lineId + ', #' + type + 'last_name_' + lineId).removeAttr("readonly");
	}
	
	$('#' + type + 'first_name_' + lineId).val(orig_first_name);
	$('#' + type + 'orig_first_name_' + lineId).val("");
	$('#' + type + 'last_name_' + lineId).val(orig_last_name);
	$('#' + type + 'orig_last_name_' + lineId).val("");
}


/**
 * Section File Upload
 */

/**
 * Edit uploaded files
 * 
 * @param fileId = file ID
 * @param id = record ID
 */
function edit_file(fileId, id){
	var json = jQuery.parseJSON($('#file_' + fileId).val());
	if(json.file_id){
		$('#id_file_id').val(json.file_id);
	}
	if(json.tempid){
		$('#id_temp_id').val(json.tempid);
	}
	$('#id_record_id').val(id);
	$('#id_fileName').val(json.file_name);
	$('#id_creator').val(json.creator);
	
	if(json.title){
		$('#id_fileTitle').val(json.title);
	}
	if(json.description){
		$('#id_fileDescription').val(json.description);
	}
	
	if(json.relation != "main_file"){
		$('#id_select_relation option[value="' + json.relation + '"]').prop('selected', true);
	}
	else {
		$('#id_select_relation option[value="main_file"]').prop('selected', true);
	}
	
	if(json.access_level == "openAccess"){
		$('#id_accessLevel_openAccess').prop('checked',true);
		$('#id_accessEmbargo').prop('disabled',true);
	}
	else if(json.access_level == "unibi"){
		$('#id_accessLevel_unibi').prop('checked',true);
		$('#id_accessEmbargo').prop('disabled',false);
	}
	else if(json.access_level == "admin"){
		if(json.request_a_copy == "1"){
			$('#id_accessLevel_request').prop('checked',true);
		}
		else {
			$('#id_accessLevel_admin').prop('checked',true);
		}
	    $('#id_accessEmbargo').prop('disabled',false);
	}

	if(json.embargo && json.embargo != ""){
	    $('#id_accessEmbargo').prop('checked',true);
	    $('#id_embargo').prop('disabled', false);
	    $('#id_embargo').val(json.embargo);
	}
	  
	var fileNameTag = self.document.getElementById('fileNameTag');
	fileNameTag.style.display = "block";
	$('#upload_file').modal('show');
}


/**
 * Delete uploaded files
 * 
 * @param fileId = file ID
 * @param id = record ID
 * @param fileName = file name
 */
function delete_file(fileId){
	if (confirm("Are you sure you want to delete this uploaded document? Any external links will be broken! If you need to update an existing file to a new version you should edit the corresponding entry in the list and re-upload the file")) {
		$('#' + fileId).remove();
	    $('#file_order_' + fileId).remove();
	    //$.post( "/upload/delete", { id: id, file_name: fileName });
	}
}

/**
 * Makes uploaded file items sortable
 */
$(function () {
	$(".dropzone").sortable({
		containerSelector: 'div.dz-preview',
	    itemSelector: 'div.dz-preview',
	    onDrop: function ($item, container, _super) {
	    	var id = $item.attr('id');
	    	$('#sortFilesInput input[value="' + id + '"]').remove();
	    	if($item.index() == 1){
	    		$('#sortFilesInput').prepend('<input type="hidden" name="file_order" id="file_order_' + id + '" value="' + id + '"/>');
	    	}
	    	else {
	    		var itemindex = $item.index() - 1;
	    		$('#sortFilesInput input:nth-child(' + itemindex + ')').after('<input type="hidden" name="file_order" id="file_order_' + id + '" value="' + id + '"/>');
	    	}
	    	$item.removeClass("dragged").removeAttr("style");
	    	$("body").removeClass("dragging");
	    }
	});
});

function add_field(name, placeholder){
	var items = $('#' + name + ' div.form-group');
	var index = items.index($('#' + name + ' div.form-group').last()) + 1;
	var blueprint = $(items[0]).clone(true,true);
	
	$(blueprint).find('input, textarea').each(function(){
		var newid = $(this).attr('id').replace(/0/g,index);
		$(this).attr('id', newid);
	});
	$('#' + name).append(blueprint);
	var abbrev = name == "department" ? "dp" : "aff";
	enable_autocomplete(abbrev, index);
}

function enable_autocomplete(field, index){
	$( "#" + field + "_autocomplete_" + index ).autocomplete({
		source: "/myPUB/autocomplete_hierarchy?fmt=autocomplete&type=department",
		minLength: 2,
		select: function( event, ui ) {
			$( "#" + field + "_autocomplete_" + index ).val( ui.item.label );
            $( "#" + field + "_nameautocomplete_" + index ).val( ui.item.label );
            $( "#" + field + "_idautocomplete_" + index ).val( ui.item.id );
            $( "#" + field + "_autocomplete_" + index ).attr("disabled", "disabled");
        }
	});
}