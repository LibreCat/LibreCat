/**
 * Dropzones
 */
$(document).ready(function(){
	Dropzone.options.qaeUpload = {
		url: '/myPUB/upload',
		maxFileSize: 1000,
		maxFiles: 1,
		previewTemplate: "<span></span>",
	    params: {access_level: "open_access", accept: 1, quickandeasy: 1},
	    createImageThumbnails: false,
	    dictDefaultMessage: "<span class=\"fa fa-file-pdf-o\" style=\"font-size:32pt;\"></span><br />Drop Open Access fulltext (pdf) here and we'll do the rest.",
	    dictMaxFilesExceeded: "Please submit or cancel your upload first before uploading more files.",
	    init: function(){
	    	$('.dz-default.dz-message').addClass('qae');
	    	this.on("addedfile", function(file) {
	        	var fileName = Dropzone.createElement("<div class=\"row\"><div class=\"progress progress-striped active\"><div class=\"progress-bar\" id=\"" + file.name + "_progress\" style=\"width: 0%;text-align:left;\"><span style=\"padding-left:10px;\">" + file.name + "</span></div></div></div>");
		        file.previewElement.appendChild(fileName);
	        });
	        this.on("uploadprogress", function(file,progress,bytesSent){
	        	var progressbar = document.getElementById(file.name + "_progress");
	            progressbar.style.width = progress + "%";
	        });
	    	this.on("success", function(file,response){
	    		var progressbar = document.getElementById(file.name + "_progress");
	            var progresselement = progressbar.parentNode.parentNode;
	            $(progresselement).remove();
	            var resp = JSON.parse(response);
	            var modal = Dropzone.createElement("<div class='well' id='" + resp.tempname + "' style='background-color:#fff;margin-left:15px;margin-right:15px;'><form id='form_" + resp.tempname + "' action='/myPUB/upload/qae/submit' method='post'><strong>" + file.name + "</strong><textarea class='form-control' placeholder='Type details about your publication here' name='description'></textarea><input type='hidden' name='file_name' value='" + resp.file_name + "' /><div class='checkbox'><label><input type='checkbox' required> I have read and accept the <a href='http://pub.uni-bielefeld.de/policy.html#depositpolicy' target='_blank'>PUB Deposit Policy</a></label></div><input type='hidden' name='tempid' value='" + resp.tempid + "' /><input type='submit' class='btn btn-default' name='submit_or_cancel' value='Submit'/><input type='reset' class='btn btn-default' onclick='location.reload()' name='submit_or_cancel' value='Cancel' /></form></div>");
	            file.previewElement.appendChild(modal);
		    });
	    	this.on("error", function(file, errorMessage){
			    var modal = Dropzone.createElement("<div class='alert alert-danger' style='margin-left:15px;margin-right:15px;'>" + errorMessage + "</div>");
			    file.previewElement.appendChild(modal);
		    });
	    },
	};
	
	Dropzone.options.uploadFiles = {
	    url: '/myPUB/upload',
	    maxFileSize: 1000,
	    previewTemplate: '<div class=\"col-md-11 dz-preview dz-file-preview\"></div>',
	    dictDefaultMessage: 'Drop files here to upload ... or click!',
	    createImageThumbnails: false,
	    
	    init: function() {
	    	$('.dz-default.dz-message').addClass('col-md-11');
	        this.on("addedfile", function(file) {
	        	var fileName = Dropzone.createElement("<div class=\"row\"><div class=\"progress progress-striped active\"><div class=\"progress-bar\" id=\"" + file.name + "_progress\" style=\"width: 0%;text-align:left;\"><span style=\"padding-left:10px;\">" + file.name + "</span></div></div></div>");
		        file.previewElement.appendChild(fileName);
	        });
	        this.on("uploadprogress", function(file,progress,bytesSent){
	        	var progressbar = document.getElementById(file.name + "_progress");
	            progressbar.style.width = progress + "%";
	        });
	        this.on("success", function(file,response){
	        	var progressbar = document.getElementById(file.name + "_progress");
	            var progresselement = progressbar.parentNode.parentNode;
	            $(progresselement).remove();
	            var resp = JSON.parse(response);
	            if(resp.success){
	              $(file.previewElement).addClass("alert alert-success");
	            	
	              var fileName = Dropzone.createElement("<div class=\"row\"><div class=\"col-md-12 padded\" id=\"filename_" + resp.tempid + "\"><span class=\"glyphicon glyphicon-file text-muted\"></span> <a href=\"[% h.shost %]/download/" + resp.file_name + "\" target=\"_blank\">" + file.name + "</a></div></div>");
	              file.previewElement.appendChild(fileName);
	              
	              var tagsRow = Dropzone.createElement("<div class=\"row\"><div class=\"col-md-2 text-muted\">Access Level:</div><div class=\"col-md-3 text-muted\">Upload Date:</div><div class=\"col-md-3 text-muted\">User:</div><div class=\"col-md-4 text-muted\">Relation:</div></div>");
	              file.previewElement.appendChild(tagsRow);
	              
	              var accessString = Dropzone.createElement("<div class=\"row\"><div class=\"col-md-2\" id=\"access_" + resp.tempid + "\"><span>" + resp.access_level + "</span></div></div>");
	              fileName.appendChild(accessString);
	              
	              var dateString = Dropzone.createElement("<div class=\"col-md-3\" id=\"updated_" + resp.tempid + "\"><span>" + resp.date_updated + "</span></div>");
	              accessString.appendChild(dateString);
	              
	              var userString = Dropzone.createElement("<div class=\"col-md-3\" id=\"creator_" + resp.tempid + "\"><span>" + resp.creator + "</span></div>");
	              accessString.appendChild(userString);
	              
	              var relationString = Dropzone.createElement("<div class=\"col-md-4\" id=\"relation_" + resp.tempid + "\"><span>" + resp.relation + "</span></div>");
	              accessString.appendChild(relationString);
	              
	              file.previewElement.appendChild(accessString);
	              
	              var removeLink = Dropzone.createElement("<div class=\"corner_up\" id=\"corup_" + resp.tempid + "\"><a href=\"#\"><span class=\"glyphicon glyphicon-remove\"></span></a></div>");
	              removeLink.addEventListener("click", function(e) {
	                window.delete_file(resp.file_id);
	              });
	              file.previewElement.appendChild(removeLink);
	              
	              var editLink = Dropzone.createElement("<div class=\"corner_down\" id=\"cordown_" + resp.tempid + "\"><a href=\"#\"><span class=\"glyphicon glyphicon-pencil\"></span></a></div>");
	              editLink.addEventListener("click", function(e) {
	                window.edit_file(resp.tempid, "[% _id %]");
	              });
	              file.previewElement.appendChild(editLink);
	              
	              var licenses = document.getElementById('licenses');
	              if(licenses){
	                var liClass = licenses.className;
	                var regexp = /collapse in/;
	                var limatch = regexp.exec(liClass);
	                if(!limatch){
	                  licenses.setAttribute("class", "collapse in");
	                }
	                $("#licenses").find('div.alert-info.mandatory').addClass('alert-danger');
	                $("#licenses").find('div.alert-info.mandatory').removeClass('alert-info');
	                $("#licenses").find('input[name="accept"]').attr('checked', false);
	              }
	              
	              file.previewElement.setAttribute("id", resp.tempid);
	              var input_element = Dropzone.createElement('<input type=\'hidden\' id=\'file_' + resp.tempid + '\' name=\'file\' value=\'' + resp.file_json + '\' />');
	              file.previewElement.appendChild(input_element);
	              
	              $('#sortFilesInput').append('<input type="hidden" name="file_order" id="file_order_' + resp.tempid + '" value="' + resp.tempid + '" />');
	            }
	        });
	    },
	};
	
	Dropzone.options.thesesUpload = {
		url: '/myPUB/thesesupload',
		maxFileSize: 1000,
		maxFiles: 1,
		previewTemplate: "<span></span>",
		previewsContainer: '#theses_dz_preview',
		params: {access_level: "open_access", accept: 1, quickandeasy: 1},
		createImageThumbnails: false,
		dictDefaultMessage: "<span class=\"fa fa-file-pdf-o\" style=\"font-size:32pt;\"></span><br />Drop your thesis here.",
		dictMaxFilesExceeded: "Please submit or cancel your upload first before uploading more files.",
		init: function(){
		 	$('.dz-default.dz-message').addClass('qae');
		 	this.on("addedfile", function(file) {
	        	var fileName = Dropzone.createElement("<div class=\"row\"><div class=\"progress progress-striped active\"><div class=\"progress-bar\" id=\"" + file.name + "_progress\" style=\"width: 0%;text-align:left;\"><span style=\"padding-left:10px;\">" + file.name + "</span></div></div></div>");
		        file.previewElement.appendChild(fileName);
	        });
	        this.on("uploadprogress", function(file,progress,bytesSent){
	        	var progressbar = document.getElementById(file.name + "_progress");
	            progressbar.style.width = progress + "%";
	        });
		   	this.on("success", function(file,response){
		   		var progressbar = document.getElementById(file.name + "_progress");
	            var progresselement = progressbar.parentNode.parentNode;
	            $(progresselement).remove();
	            var resp = JSON.parse(response);
	            var well = Dropzone.createElement("<div class='well' id='" + resp.tempid + "' style='background-color:#fff;margin-left:15px;margin-right:15px;'></div>");
	            
	            var form = Dropzone.createElement("<form class='form-horizontal' id='form_" + resp.tempid + "' action='/myPUB/thesesupload/submit' method='post'></form>");
	            
	            var file_name = Dropzone.createElement("<h4 class='expert'><span class='fa fa-file-pdf-o'></span> " + file.name + "</h4>");
	            form.appendChild(file_name);
	            
	            var type = Dropzone.createElement("<div class='form-group'><div class='col-sm-offset-2 col-sm-10'><div class='radio'><label><input type='radio' name='type' value='biDissertation' checked='checked'>Dissertation</label></div><div class='radio'><label><input type='radio' name='type' value='biMasterThesis'>Master Thesis</label></div><div class='radio'><label><input type='radio' name='type' value='biBachelorThesis'>Bachelor Thesis</label></div><div class='radio'><label><input type='radio' name='type'' value='biPostdocThesis'>Postdoc Thesis/Habilitation</label></div></div></div>");
	            form.appendChild(type);
	            
	            var title = Dropzone.createElement("<div class='form-group'><label for='id_title' class='col-sm-2 control-label'>Title<span class='starMandatory'></span></label><div class='col-sm-10'><input type='text' name='title' class='form-control' id='id_title' placeholder='Title' required /></div></div>");
	            form.appendChild(title);
	            
	            var author = Dropzone.createElement("<div class='form-group'><label class='col-sm-2 control-label'>Author<span class='starMandatory'></span></label><div class='col-sm-5'><input type='text' name='author.first_name' class='form-control' placeholder='First Name' required /></div><div class='col-sm-5'><input type='text' name='author.last_name' class='form-control' placeholder='Last Name' /></div></div>");
	            form.appendChild(author);
	            
	            var email = Dropzone.createElement("<div class='form-group'><label for='id_email' class='col-sm-2 control-label'>Email<span class='starMandatory'></span></label><div class='col-sm-10'><input type='email' class='form-control' id='id_email' placeholder='Email' name='email' required /></div></div>");
	            form.appendChild(email);
	            
	            var supervisor = Dropzone.createElement("<div class='form-group'><label class='col-sm-2 control-label'>Supervisor<span class='starMandatory'></span></label><div class='col-sm-5'><input type='text' name='supervisor.first_name' class='form-control' placeholder='First Name' required /></div><div class='col-sm-5'><input type='text' name='supervisor.last_name' class='form-control' placeholder='Last Name' /></div></div>");
	            form.appendChild(supervisor);
	            
	            var hidden = Dropzone.createElement("<input type='hidden' name='file_name' value='" + resp.file_name + "' />");
	            var hidden2 = Dropzone.createElement("<input type='hidden' name='tempid' value='" + resp.tempid + "' />");
	            form.appendChild(hidden);
	            form.appendChild(hidden2);
	            
	            var buttons = Dropzone.createElement("<div class='form-group'><div class='col-sm-10 col-sm-offset-2'><input type='submit' class='btn btn-default' name='submit_or_cancel' onclick='return confirm(\"I herewith place this document at the disposal of Bielefeld University for the purpose of storing in electronic form and making it available to the public according to the PUB Deposit Policy.\");' value='Submit'/><input type='submit' class='btn btn-default' name='submit_or_cancel' value='Cancel' /></div></div>");
	            form.appendChild(buttons);
	            
	            well.appendChild(form);
	            file.previewElement.appendChild(well);
		    });
		   	this.on("error", function(file, errorMessage){
			    var modal = Dropzone.createElement("<div class='alert alert-danger' style='margin-left:15px;margin-right:15px;'>" + errorMessage + "</div>");
			    file.previewElement.appendChild(modal);
		    });
		},
	};
});