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

// Function to extract digits from a string and return as an array
function extract_digits(a) {
    var arr2 = newArray; // tableau de retour contenant les nombres extraits
    for (var i = 0; i < a.length; i++) {
        var str = a[i];
        var digits = "";
        var foundDigit = false;
        for (var j = 0; j < str.length; j++) {
            var ch = str.substring(j, j + 1);
            if (!isNaN(parseInt(ch))) {
                digits += ch;
                foundDigit = true;
            } else if (foundDigit) {
                break;
            }
        }
        arr2[i] = parseInt(digits);
    }
    return arr2;
}

dir = getDirectory("Choose Source Directory ");
list = getFileList(dir);
setBatchMode(true);

for (i=0; i<list.length; i++) {
    showProgress(i+1, list.length);
    
    filename = dir + list[i];

    tseriesFoldersList = getFileList(filename);
    tseriesFolderFound = false;
    var tseriesFolders = newArray();
    
    for (var j = 0; j < tseriesFoldersList.length; j++) {
         if (startsWith(tseriesFoldersList[j], "TSeries") && File.isDirectory(filename + tseriesFoldersList[j])) {
            tseriesFolderFound = true;
            tseriesFolders = Array.concat(tseriesFolders, filename + tseriesFoldersList[j]);
         	}
  	   	}
		 if (!tseriesFolderFound) {
		     print("No 'TSeries' folder found in '" + tseriesFoldersList + "'. Exiting macro.");
		        continue;
		        }
			
		    // Iterate over 'TSeries' folders
		    for (tseriesFolderIndex = 0; tseriesFolderIndex < tseriesFolders.length; tseriesFolderIndex++) {
		        tseriesFolder = tseriesFolders[tseriesFolderIndex];
		        print(tseriesFolder);
		    
			    // Check if 'suite2p' subfolder exists
			    suite2pFolder = tseriesFolder + "suite2p/";
			    
			    if (!File.isDirectory(suite2pFolder)) {
			        print("Skipping " + tseriesFolder + ": No 'suite2p' subfolder found.");
			        continue; 
			    	}
			
			    // List 'plane' folders in suite2pFolder
			    planeFolders = getFileList(suite2pFolder);
			    var validPlaneFolders = newArray();
			    
			    for (var k = 0; k < planeFolders.length; k++) {
			        if (startsWith(planeFolders[k], "plane") && File.isDirectory(suite2pFolder + planeFolders[k])) {
			            validPlaneFolders = Array.concat(validPlaneFolders, suite2pFolder + planeFolders[k] + "/");
			        }
			    }
			    
			    if (validPlaneFolders.length == 0) {
			        print("Skipping " + suite2pFolder + ": No 'plane' folders found.");
			        continue;
			    	}
			
			    // Iterate over 'plane' folders
			    for (var planeFolderIndex = 0; planeFolderIndex < validPlaneFolders.length; planeFolderIndex++) {
			        planeFolder = validPlaneFolders[planeFolderIndex];
			
			        // Check if 'reg_tif' folder exists in plane folder
			        regTifFolder = planeFolder + "reg_tif/";
			        if (File.isDirectory(regTifFolder)) {
			            tifFiles = getFileList(regTifFolder);
			            arr_num = extract_digits(tifFiles);
						Array.sort(arr_num, tifFiles);
			
			            var filesToConcatenate = newArray();
			            var hasTifFiles = false;
			
			
			            for (var l = 0; l < tifFiles.length; l++) {
			                file = regTifFolder + tifFiles[l];
			                open(file);
			                print("Opening file: " + file);
			
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
			                fullPath = regTifFolder + fileName;
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
