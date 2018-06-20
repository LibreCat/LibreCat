/**
 * Dropzones
 */
$(document).ready(function(){
    var htmlEscape = function(str) {
        return str
            .replace(/&/g, '&amp;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
    };

    Dropzone.options.qaeUpload = {
        url: librecat.uri_base + '/librecat/upload',
        maxFilesize: 500,
        maxFiles: 1,
        previewTemplate: "<span></span>",
        params: {access_level: "open_access", accept: 1, quickandeasy: 1},
        createImageThumbnails: false,
        addRemoveLinks: true,
        dictMaxFilesExceeded: "Please submit or cancel your upload first before uploading more files.",
        init: function(){
            $('.dz-default.dz-message').addClass('qae');
            this.on("addedfile", function(file) {
                var fileName = Dropzone.createElement("<div class=\"row\"><div class=\"progress progress-striped active\"><div class=\"progress-bar\" id=\"" + file.name + "_progress\" style=\"width:0;text-align:left;padding-left:10px;\">" + file.name + "</span></div></div></div>");
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
                var resp = response;//JSON.parse(response);
                var modal = Dropzone.createElement(
"<div class='well' id='" + resp.tempname + "'>" +
"<form id='form_" + resp.tempname + "' action='" + librecat.uri_base + "/librecat/upload/qae/submit' method='post'>" +
"<strong>" + file.name + "</strong>" +
"<textarea class='form-control' placeholder='Type details about your publication here' name='description'>" +
"</textarea>" +
"<input type='hidden' name='reviewer' value='" + $('#qaeUpload').data('reviewer') + "' />" +
"<input type='hidden' name='project_reviewer' value='" + $('#qaeUpload').data('project_reviewer') + "' />" +
"<input type='hidden' name='delegate' value='" + $('#qaeUpload').data('delegate') + "'/>" +
"<input type='hidden' name='file_name' value='" + resp.file_name + "' />" +
"<div class='checkbox'>" +
"<label>" +
"<input type='checkbox' required> I have read and accept the <a href='" + librecat.uri_base + "/docs/howto/policy#depositpolicy' target='_blank'>PUB Deposit Policy</a>" +
"</label>" +
"</div>" +
"<input type='hidden' name='tempid' value='" + resp.tempid + "' />" +
"<input type='submit' class='btn btn-success' name='submit_or_cancel' value='Submit'/>" +
"<input type='reset' class='btn btn-warning' onclick='location.reload()' name='submit_or_cancel' value='Cancel' />" +
"</form></div>"
                );
                file.previewElement.appendChild(modal);
            });
            this.on("error", function(file, errorMessage){
                var modal = Dropzone.createElement("<div class='alert alert-danger'>" + errorMessage + "</div>");
                file.previewElement.appendChild(modal);
            });
            this.on("complete", function(file){
    		    var remove_link = file.previewElement.getElementsByClassName('dz-remove');
    			$(remove_link).remove();
    		});
        },
    };

    Dropzone.options.uploadFiles = {
        url: librecat.uri_base + '/librecat/upload',
        maxFilesize: 500,
        previewTemplate: '<div class=\"col-md-11 dz-preview dz-file-preview\"></div>',
        createImageThumbnails: false,
        addRemoveLinks: true,
        init: function() {
            $('.dz-default.dz-message').addClass('col-md-11');
            this.on("addedfile", function(file) {
                var fileName = Dropzone.createElement("<div class=\"row\"><div class=\"progress progress-striped active\"><div class=\"progress-bar\" id=\"" + file.name + "_progress\" style=\"width:0;text-align:left;padding-left:10px;\">" + file.name + "</span></div></div></div>");
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
                var resp = response;
                if(resp.success){
                    $(file.previewElement).addClass("alert alert-success");

                    var fileName = Dropzone.createElement("<div class=\"row\"><div class=\"col-md-12 padded text-muted\" id=\"filename_" + resp.tempid + "\"><span class=\"fa fa-file text-muted\"></span> <strong>" + file.name + "</strong></div></div>");
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

                    var removeLink = Dropzone.createElement("<div class=\"corner_up\" id=\"corup_" + resp.tempid + "\"><a href=\"#\"><span class=\"fa fa-times\"></span></a></div>");
                    removeLink.addEventListener("click", function(e) {
                        window.delete_file(resp.tempid);
                        e.preventDefault();
                    });
                    file.previewElement.appendChild(removeLink);

                    var editLink = Dropzone.createElement("<div class=\"corner_down\" id=\"cordown_" + resp.tempid + "\"><a href=\"#\" onclick=\"return false;\"><span class=\"fa fa-pencil\"></span></a></div>");
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
                        $('#licenses').find('#select_ddc_0').addClass('required');
                        $('#licenses').find('#select_ddc_0').closest('div.input-group').addClass('mandatory');
                        $('#licenses').find('#select_ddc_0').addClass('has-error');
                        $('#licenses').find('#select_ddc_0').closest('div.input-group.mandatory').addClass("has-error");
                        $('#licenses').find('label[for="select_ddc_0"]').closest('div').append('<span class="starMandatory"></span>');
                    }

                    file.previewElement.setAttribute("id", resp.tempid);
                    var input_element = Dropzone.createElement(
                        '<input type="hidden" id="file_' + resp.tempid + '" name="file" value="' + htmlEscape(JSON.stringify(resp)) + '" />'
                    );
                    file.previewElement.appendChild(input_element);
                }
            });
            this.on("error", function(file, errorMessage){
                var modal = Dropzone.createElement("<div class='alert alert-danger'>" + errorMessage + "</div>");
                file.previewElement.appendChild(modal);
            });
            this.on("complete", function(file){
    		    var remove_link = file.previewElement.getElementsByClassName('dz-remove');
    			$(remove_link).remove();
    		});
        },
    };
});
