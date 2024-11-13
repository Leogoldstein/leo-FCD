// Function to open a folder selection dialog
function selectFolderDialog(prompt) {
    return getDirectory(prompt);
}

// Function to concatenate multiple TIFF files
function concatenateTiffFiles(tiffFiles) {
    var command = "title=Concatenated image";
    for (var i = 0; i < tiffFiles.length; i++) {
        command += " image" + (i + 1) + "=[" + tiffFiles[i] + "]";
    }
    run("Concatenate...", command);
}

// Function to add empty slices to make the stack size a multiple of ten
function addSlicesToMakeMultipleOfTen() {
    var stackSize = nSlices;
    var slicesToAdd = (10 - (stackSize % 10)) % 10;
    for (var i = 0; i < slicesToAdd; i++) {
        run("Add Slice");
    }
}

function extract_digits(a) {
    var arr2 = newArray; // tableau de retour contenant les nombres extraits
    for (var i = 0; i < a.length; i++) {
        var str = a[i];
        var digits = "";
        var foundDigit = false;
        for (var j = 0; j < str.length; j++) {
            var ch = str.substring(j, j+1);
            if (!isNaN(parseInt(ch))) {
                digits += ch;
                foundDigit = true;
            } else if (foundDigit) {
                // Si nous avons déjà trouvé des chiffres et rencontrons un non-chiffre,
                // nous arrêtons de rechercher des chiffres pour trier correctement
                break;
            }
        }
        arr2[i] = parseInt(digits);
    }
    return arr2;
}

// Main macro
macro "Select Folder and Concatenate TIFFs" {
    // Ask user to select a folder
    var selectedFolder = selectFolderDialog("Select a folder");

    // Check if a folder was selected
    if (selectedFolder == "") {
        print("No folder selected. Exiting macro.");
        exit();
    }

    // Select TSeries Folders
    print("Selected folder: " + selectedFolder);

    var tseriesFoldersList = getFileList(selectedFolder);
    tseriesFolderFound = false;
    var tseriesFolders = newArray();
        
    for (var j = 0; j < tseriesFoldersList.length; j++) {
         if (startsWith(tseriesFoldersList[j], "TSeries") && File.isDirectory(selectedFolder + tseriesFoldersList[j])) {
            tseriesFolderFound = true;
            tseriesFolders = Array.concat(tseriesFolders, selectedFolder + tseriesFoldersList[j]);
         	}
   		 }
   	if (!tseriesFolderFound) {
        print("No 'TSeries' folder found in '" + selectedFolder + "'. Exiting macro.");
        continue;
        }
    
    // Iterate over 'TSeries' folders
    for (var tseriesFolderIndex = 0; tseriesFolderIndex < tseriesFolders.length; tseriesFolderIndex++) {
        var tseriesFolder = tseriesFolders[tseriesFolderIndex];
        print(tseriesFolder);
    
	    // Check if 'suite2p' subfolder exists
	    var suite2pFolder = tseriesFolder + "suite2p/";
	    
	    if (!File.isDirectory(suite2pFolder)) {
	        print("Skipping " + tseriesFolder + ": No 'suite2p' subfolder found.");
	        continue; 
	    }
	
	    // List 'plane' folders in suite2pFolder
	    var planeFolders = getFileList(suite2pFolder);
	    var validPlaneFolders = newArray();
	    
	    for (var j = 0; j < planeFolders.length; j++) {
	        if (startsWith(planeFolders[j], "plane") && File.isDirectory(suite2pFolder + planeFolders[j])) {
	            validPlaneFolders = Array.concat(validPlaneFolders, suite2pFolder + planeFolders[j] + "/");
	        }
	    }
	    
	    if (validPlaneFolders.length == 0) {
	        print("Skipping " + suite2pFolder + ": No 'plane' folders found.");
	        continue;
	    }
	
	    // Iterate over 'plane' folders
	    for (var planeFolderIndex = 0; planeFolderIndex < validPlaneFolders.length; planeFolderIndex++) {
	        var planeFolder = validPlaneFolders[planeFolderIndex];
	
	        // Check if 'reg_tif' folder exists in plane folder
	        var regTifFolder = planeFolder + "reg_tif/";
	        if (File.isDirectory(regTifFolder)) {
	            var tifFiles = getFileList(regTifFolder);
	            var arr_num = extract_digits(tifFiles);
				Array.sort(arr_num, tifFiles);
	
	            var filesToConcatenate = newArray();
	            var hasTifFiles = false;
	
	
	            for (var i = 0; i < tifFiles.length; i++) {
	                var file = regTifFolder + tifFiles[i];
	                open(file);
	                //print("Opening file: " + file);
	
	                // Add empty slices to make the stack size a multiple of ten
	                addSlicesToMakeMultipleOfTen();
	
	                filesToConcatenate = Array.concat(filesToConcatenate, getTitle());
	                hasTifFiles = true;
	            }

            // Concatenate stacks
            if (hasTifFiles) {
                concatenateTiffFiles(filesToConcatenate);

                // Apply grouped Z projection
                run("Grouped Z Project...", "projection=[Average Intensity] group=10");
				run("Time Stamper", "starting=0 interval=0.3333333333333333 x=15 y=15 font=12 decimal=0 anti-aliased or=sec");
				
                var fileName = "AVG_concat.tif";
                var fullPath = regTifFolder + fileName;
                saveAs("Tiff", fullPath);

                // Close all images
                run("Close All");
            } else {
                print("No .tif files found in " + regTifFolder + ".");
            }
        } else {
            print("No 'reg_tif' folder found in " + planeFolder + ".");
        }
    }
}
}