// D'abord faire la correction de mouvements avec suite2p
// Mettre camera dans TSeries !!!


// Main logic pour gérer les sous-dossiers en fonction de 'name'
var PathSave = "D:" + File.separator + "Imaging" + File.separator;
var dir = getDirectory("Choose Source Directory ");
var list = getFileList(dir);
setBatchMode(true);

for (var i = 0; i < list.length; i++) {
    var filename = dir + list[i];
    print("Traitement du fichier : " + filename);
    
    var name = File.getName(filename);
    
    var parentFolder = File.getParent(filename); 
    var type = parentFolder.substring(parentFolder.lastIndexOf(File.separator) + 1);
    
    var StartDirList = getFileList(filename);
    var rootDir = PathSave + type + File.separator + name + File.separator;
    createDirectory(rootDir);
    
    // Pour chaque élément de StartDirList
    for (var j = 0; j < StartDirList.length; j++) {
        var StartDir = filename + StartDirList[j];   // ex : ...\mTor13/ani2/
        
        // Si le nom commence par "mTor", traitement des sous-dossiers niveau 2
        if (matches(name, "^m[Tt]or.*")) {

            // ani = "ani2/" -> "ani2"
            var ani = replace(StartDirList[j], "/", "");
            var animal = rootDir + ani + File.separator;    // ...\mTor13\ani2\
            createDirectory(animal);

            if (File.isDirectory(StartDir)) {
                var dates = getFileList(StartDir);     // ex : 2024-10-25/

                if (dates.length > 0) {
                    for (var k = 0; k < dates.length; k++) {

                        // ex : ...\mTor13/ani2/2024-10-25/
                        var date = StartDir + dates[k];
                        // normaliser les séparateurs
                        var date = replace(date, "/", File.separator);

                        var date = replace(dates[k], "/", "");   // 2024-10-25
                        
                        var BaseDir = animal + date + File.separator;    // ...\mTor13\ani2\2024-10-25\
                        createDirectory(BaseDir);
                        
                        var saveSingleImDir = BaseDir + "Single images" + File.separator;
                        createDirectory(saveSingleImDir);
                        
                        // Traiter les dossiers "SingleImage" dans date
                        handleSingleImages(BaseDir, saveSingleImDir);
                        
                        // Vérifier et créer l'AVI enregistré pour les TSeries dans date
                        handleCamAndTSeries(BaseDir);
                    }
                }
            }    
        }
        
        // Si le nom commence par "ani", traitement des sous-dossiers niveau 1
        else if (name.startsWith("an")) {
            var date = replace(StartDirList[j], "/", "");
            
            var BaseDir = rootDir + date + File.separator;
            createDirectory(BaseDir);
        
            var saveSingleImDir = BaseDir + "Single images" + File.separator;
            createDirectory(saveSingleImDir);
        
            // Traiter les dossiers "SingleImage" dans StartDir
            handleSingleImages(BaseDir, saveSingleImDir);
            
            // Vérifier et créer l'AVI enregistré
            handleCamAndTSeries(BaseDir);
        }
    }
}

setBatchMode(false);

/// =================================== Related functions =============================================================

// Fonction pour gérer les images dans "SingleImage"
function handleSingleImages(BaseDir, saveSingleImDir) {
    var SubFolders = getFileList(BaseDir);
    for (var m = 0; m < SubFolders.length; m++) {
        if (startsWith(SubFolders[m], "SingleImage") && File.isDirectory(StartDir + File.separator + SubFolders[m])) {
            var SingleImageFolder = BaseDir + SubFolders[m];
            var tifFiles = getFileList(SingleImageFolder);
            for (var n = 0; n < tifFiles.length; n++) {
                if (endsWith(tifFiles[n], ".ome.tif")) {
                    var tifFilePath = SingleImageFolder + tifFiles[n];
                    //print("tifFilePath : " + tifFilePath);
                    processTifFile(tifFilePath, saveSingleImDir);
                }
            }
        } else {
            print("No SingleImages found in " + SubFolders[m] + ".");
        }
    }
}

// Fonction pour traiter un fichier TIFF
function processTifFile(tifFilePath, saveDir) {
    var tifFileName = File.getName(tifFilePath);
    print("tifFileName : " + tifFileName);
    	
    var pattern = "(.*)_(Cycle[0-9]+)_(Ch[0-9]+)_(\\d{6})\\.ome.tif"; // Adjusted for 5 underscores
    if (matches(tifFileName, pattern)) {
        var values = split(tifFileName, "_");
        var channel = values[2]; // Now correctly points to Ch1, Ch2, Ch3

        var newFileName = replace(tifFileName, ".ome.tif", ".tif");
        var fullPath = saveDir + File.separator + newFileName;

        if (File.exists(fullPath)) {
            print("L'image " + channel + " existe déjà : " + fullPath); 
            return;
        }

        if (File.exists(tifFilePath)) {
		    open(tifFilePath);
	
	        if (channel == "Ch2") {
	            run("Green");
	        } else if (channel == "Ch1") {
	            run("Red");
	        } else if (channel == "Ch3") {
	            run("Blue");
	        } else {
	            print("Canal non reconnu : " + channel);
	            return;
	        }
	
	        print("Saving to: " + fullPath);
	        saveAs("Tiff", fullPath);
	        
	    } else {
		    print("Fichier non trouvé ou format non supporté : " + tifFilePath);
		}

    } else {
        print("Nom du fichier ne correspond pas au modèle attendu.");
    }
}


// Fonction pour gérer les TSeries et l'AVI enregistré
function handleCamAndTSeries(BaseDir) {
	
    var tseriesFoldersList = getFileList(BaseDir);
    var tseriesFolders = newArray();
    var tseriesFolderFound = false;

    // Chercher les dossiers TSeries
    for (var l = 0; l < tseriesFoldersList.length; l++) {
        if (startsWith(tseriesFoldersList[l], "TSeries") 
            && File.isDirectory(BaseDir + File.separator + tseriesFoldersList[l])) {
            
            tseriesFolderFound = true;
            // chemin complet du TSeries
            tseriesFolders = Array.concat(tseriesFolders, BaseDir + File.separator + tseriesFoldersList[l] + File.separator);
        }
    }

    if (!tseriesFolderFound) {
        print("No 'TSeries' folder found in '" + BaseDir + "'. Skipping this directory.");
        return;
    }

	// Itérer sur les dossiers 'TSeries'
	for (var tseriesFolderIndex = 0; tseriesFolderIndex < tseriesFolders.length; tseriesFolderIndex++) {
	    
	    var tseriesFolder = tseriesFolders[tseriesFolderIndex];
	    var tseriesFolderName = File.getName(tseriesFolder);

	    var proceed = false;
	    
	    print("==========");
	    print("TSeries folder found: " + tseriesFolder);
	    
	    // Vérifier si le sous-dossier 'suite2p' existe
	    var suite2pFolder = tseriesFolder + File.separator + "suite2p" + File.separator;                            
	    if (!File.isDirectory(suite2pFolder)) {
	        print("Skipping " + tseriesFolder + ": No 'suite2p' subfolder found.");
	        continue; 
	    }
	                
	    // Lister les dossiers 'plane' dans suite2pFolder
	    var inside = getFileList(suite2pFolder);
	    var PlaneFolderList = newArray();
	                
	    for (var m = 0; m < inside.length; m++) {
	        if (startsWith(inside[m], "plane") && File.isDirectory(suite2pFolder + File.separator + inside[m])) {
	                
	            var PlaneFolder = suite2pFolder + File.separator + inside[m] + File.separator;
	                
	            // Ajouter dans la liste
	            PlaneFolderList = Array.concat(PlaneFolderList, PlaneFolder);			
	        }
	    }
	             
	    if (PlaneFolderList.length == 0) {
	        print("Skipping " + suite2pFolder + ": No 'plane' folders found.");
	        continue;
	    }
	    
	    var files = getFileList(tseriesFolder);
	    
	    // Itérer sur les dossiers 'plane'
	    for (var planeFolderIndex = 0; planeFolderIndex < PlaneFolderList.length; planeFolderIndex++) {
	                
	        var planeFolder = PlaneFolderList[planeFolderIndex];
	        var regTifFolder = planeFolder + "reg_tif" + File.separator;
	        
	        var planeName = File.getName(planeFolder);
	        var savePlaneFolder = tseriesFolder + File.separator + planeName + File.separator;
	        createDirectory(savePlaneFolder);
	      
	        processRegTifFolder(regTifFolder, savePlaneFolder, tseriesFolderName);
	    }
	    
	    // Gestion des images caméra
	    var saveCamImDir;
	                    
	    if (File.isDirectory(tseriesFolder + File.separator + "cam" + File.separator)) {
	        saveCamImDir = tseriesFolder + File.separator + "cam" + File.separator;
	        proceed = true;
	    } else if (File.isDirectory(tseriesFolder + File.separator + "camera" + File.separator)) {
	        saveCamImDir = tseriesFolder + File.separator + "camera" + File.separator;
	        proceed = true;
	    } else {
	        print("  No Camera images found in " + tseriesFolder + ".");
	    }
	                    
	    if (proceed) {
	        print("  Traitement des images caméra dans " + saveCamImDir);
	        handleCamImages(saveCamImDir);
	        
	        var CombinedSavePath = tseriesFolder + "Combined" + File.separator;
		    createDirectory(CombinedSavePath);
		
		    var CombinedFilePath = CombinedSavePath + "Combine.tif";
		    
		    if (!File.exists(CombinedFilePath)) {
 	
		    	for (var planeFolderIndex = 0; planeFolderIndex < PlaneFolderList.length; planeFolderIndex++) {
		    		
		    		var planeFolder = PlaneFolderList[planeFolderIndex];
			        var planeName = File.getName(planeFolder);
			        var savePlaneFolder = tseriesFolder + File.separator + planeName + File.separator;
		        
		    		var GroupZTiffPlane  = savePlaneFolder + File.separator + "AVG_groupZ.tif";
		    		open(GroupZTiffPlane);
		    		var GroupZ = getTitle();
		               							  
		            if (isOpen(GroupZ));{
	
			            run("8-bit");
			            
			            // Créer l'image de fond				
			            var newGroupZ = "plane" + planeFolderIndex;
			            var stackSize = nSlices;		
			            newImage(newGroupZ, "8-bit black", 612, 562, stackSize);	
			            
			            run("Insert...", "source=[" + GroupZ + "] destination=[" + newGroupZ + "] x=50 y=50");
			            
			            // Time Stamper seulement pour le premier
			            if (PlaneFolderList.length == 1) {
			                run("Time Stamper", "starting=0 interval=0.30 x=10 y=40 font=25 decimal=0 anti-aliased or=sec");
			            } else {
			            	if (planeFolderIndex == 0) {
			            		run("Time Stamper", "starting=0 interval=1.37 x=10 y=40 font=25 decimal=0 anti-aliased or=sec");
			            }
			            selectWindow(GroupZ);
			            // Créer une nouvelle stack caméra sous-échantillonnéeclose();
			            }
			        }
		    	}
			
			    var CamFile = saveCamImDir + "Concatenated" + File.separator + "cam_crop.tif";
			    open(CamFile);
				
				if (isOpen(CamFile));{
					
					CamFileName = getTitle();
					nCam = nSlices;

				    if (PlaneFolderList.length == 1) {

					    // garder 2,12,22,... (increment = 10)
					    run("Slice Keeper", "first=2 last=" + nCam + " increment=10");
					    var resizeCamFile = getTitle();
   						
   						resizeStackToHeight(resizeCamFile, 512);
				
				        newW_background = newW + 100;
				        newImage("new cam_crop.tif kept stack", "8-bit black", newW_background, 612, nCam);
				
				        // Insérer la projection dans le fond
				        run("Insert...", 
				            "source=["+ resizeCamFile +"] destination=[new cam_crop.tif kept stack] x=50 y=50"
				        );
				
				        run("Combine...", 
				            "stack1=[plane0] stack2=[new cam_crop.tif kept stack]"
				        );
				        
				        saveAs("Tiff", CombinedFilePath);
				
				        run("Close All");
				
				    } else if (PlaneFolderList.length > 1) {
		
				        // Combine verticalement les différents plans
				        run("Combine...", 
				            "stack1=[plane0] stack2=[plane1] combine"
				        );
				        
				        run("Combine...", 
				            "stack1=[Combined Stacks] stack2=[plane2] combine"
				        );
				        
				        rename("Combined Plane Stacks");
				        nTSeries = nSlices;
						
				        // Calcul du facteur temporel
				        ratio = nCam * 1.0 / nTSeries;
				
				        // Construire la liste d’indices à garder dans la cam
				        indices = "";
						for (i = 0; i < nTSeries; i++) {
						
						    idx = floor(i * ratio + 0.5) + 1;
						    if (idx > nCam) idx = nCam;
						
						    if (i > 0)
						        indices = indices + ",";
						
						    indices = indices + idx;
						}
				        
				        selectWindow(CamFileName);
				        
						// Créer une nouvelle stack caméra sous-échantillonnée
				        run("Make Substack...", "slices=" + indices + " delete do_not");
				        rename("cam_resampled");
				        cam_resampled = getTitle();
   
				        resizeStackToHeight(cam_resampled, 900);
				        w = getWidth();
				        
				        // Récupérer les dimensions de Combined Stacks
				        selectWindow("Combined Plane Stacks");
				        h = getHeight();
				        n = nSlices;
				
				        // Créer une nouvelle image
				        newImage("Combined_with_cam", "8-bit black", w, h, n);
				
				        // Taille de la pile caméra
				        selectWindow("cam_resampled");
				        camW = getWidth();
				        camH = getHeight();
				
				        // Centrage
				        offsetX = floor((w - camW) / 2);
				        offsetY = floor((h - camH) / 2);
				
				        // Insertion
				        run("Insert...", 
				            "source=[cam_resampled] destination=[Combined_with_cam] x=" + offsetX + " y=" + offsetY
				        );
				
				        // Combiner les deux stacks
				        run("Combine...", 
				            "stack1=[Combined Plane Stacks] stack2=[Combined_with_cam]"
				        );
						
						saveAs("Tiff", CombinedFilePath);
				        run("Close All");
				    }
				}
		    } else {
				print("Le fichier Tiff combiné existe déjà : " + CombinedFilePath);
		    }
	    }
	}
}

function processRegTifFolder(regTifFolder, savePlaneFolder, tseriesFolderName) {

    // Vérifier que le dossier reg_tif existe
    if (!File.isDirectory(regTifFolder)) {
        print("Aucun dossier 'reg_tif' trouvé dans : " + regTifFolder);
        return "";
    }

    // Récupérer la liste des .tif
    var tifFiles = getFileList(regTifFolder);
    if (tifFiles.length == 0) {
        print("Aucun fichier .tif trouvé dans " + regTifFolder);
        return "";
    }

    // Noms des fichiers de sortie
    var ConcatenatedTiffPlane = savePlaneFolder + File.separator + "Concatenated.tif";
    var GroupZTiffPlane       = savePlaneFolder + File.separator + "AVG_groupZ.tif";
    var ZProject              = savePlaneFolder + File.separator + "Zproject.tif";

    // Déterminer si c’est une série "blue" ou non
    // blue → indexOf(...) >= 0 ; non-blue → < 0
    var isBlue = (indexOf(tseriesFolderName, "blue") >= 0);

    // CAS 1 : plusieurs fichiers et pas encore de Concatenated.tif
    if (!File.exists(ConcatenatedTiffPlane) && tifFiles.length > 1) {

        // Tri des fichiers en fonction des chiffres dans le nom
        var arr_num = extract_digits(tifFiles);
        Array.sort(arr_num, tifFiles);

        var filesToConcatenate = newArray();
        var hasTifFiles = false;

        // Ouvrir chaque fichier et adapter le nombre de slices
        for (var n = 0; n < tifFiles.length; n++) {
            var file = regTifFolder + File.separator + tifFiles[n];
            open(file);

            // Ajouter des tranches vides pour que la pile soit un multiple de 10
            addSlicesToMakeMultipleOfTen();

            filesToConcatenate = Array.concat(filesToConcatenate, getTitle());
            hasTifFiles = true;
        }

        if (!hasTifFiles) {
            print("Aucun .tif valide à concaténer dans " + regTifFolder);
            return "";
        }

        // Concaténer les piles
        concatenateTiffFiles(filesToConcatenate);

        if (isBlue) {
            // Blue → seulement Z Project simple
            run("Z Project...", "projection=[Average Intensity]");
            run("Enhance Contrast", "saturated=0.35");
            saveAs("Tiff", ZProject);
        } else {
            // Non-blue → sauvegarde concaténée + Grouped Z Project
            saveAs("Tiff", ConcatenatedTiffPlane);

            if (!File.exists(GroupZTiffPlane)) {
                run("Grouped Z Project...", "projection=[Average Intensity] group=10");
                // run("Time Stamper", "starting=0 interval=0.2987373388 x=15 y=15 font=12 '00 decimal=0 or=sec");
                // run("Animation Options...", "speed=30 first=1 last=" + nSlices);
                saveAs("Tiff", GroupZTiffPlane);
            }
        }

    // CAS 2 : Concatenated.tif existe déjà, plusieurs fichiers, non-blue, mais pas de GroupZTiffPlane
    } else if (!File.exists(GroupZTiffPlane)
               && tifFiles.length > 1
               && !isBlue) {

        open(ConcatenatedTiffPlane);

        // S’assurer que le nombre de slices est multiple de 10
        addSlicesToMakeMultipleOfTen();

        run("Grouped Z Project...", "projection=[Average Intensity] group=10");
        // run("Time Stamper", "starting=0 interval=0.2987373388 x=15 y=15 font=12 '00 decimal=0 or=sec");
        // run("Animation Options...", "speed=30 first=1 last=" + nSlices);

        saveAs("Tiff", GroupZTiffPlane);

    // CAS 3 : un seul fichier, pas de Concatenated.tif
    } else if (!File.exists(ConcatenatedTiffPlane)
               && tifFiles.length == 1
               && isBlue) {

        var file = regTifFolder + File.separator + tifFiles[0];
        open(file);

        // Pour un seul fichier : Z Project simple (blue ou non-blue)
        run("Z Project...", "projection=[Average Intensity]");
        run("Enhance Contrast", "saturated=0.35");
        saveAs("Tiff", ZProject);
    }

    run("Close All");
}


// Fonction pour gérer les images dans "camera"
function handleCamImages(saveCamImDir) {
	
	var saveCamConcatImDir = saveCamImDir + "Concatenated";
    createDirectory(saveCamConcatImDir);
     
	var finalConcatName = saveCamConcatImDir + File.separator + "cam_crop.tif";	
	if (File.exists(finalConcatName)) {
			print("Le fichier cam_crop.tif existe déjà : " + finalConcatName);
			return; // Passer à l'itération suivante sans faire de calculs supplémentaires                           
	}
		 
    var tifFiles = getFileList(saveCamImDir);               
    var hasTifFiles = false;

    var batchSize = 500;
    var batchIndex = 1;
    var intermediateFiles = newArray();
    
    var totalFiles = tifFiles.length;
	var numBatches = Math.ceil(totalFiles / batchSize);
	var finalFilesToConcat = newArray();
	
	for (var batch = 0; batch < numBatches; batch++) {
	    var startIndex = batch * batchSize;
	    var endIndex = Math.min(startIndex + batchSize - 1, totalFiles - 1);
	    var filesToConcatenate = newArray();
	
	    print("Batch " + (batch + 1) + " : " + startIndex + " à " + endIndex);
	
	    for (var i = startIndex; i <= endIndex; i++) {        
	        if (endsWith(tifFiles[i], ".tif") || endsWith(tifFiles[i], ".tiff")) {
	            var file = saveCamImDir + File.separator + tifFiles[i];
	            open(file);
	            filesToConcatenate = Array.concat(filesToConcatenate, getTitle());
	            hasTifFiles = true;
	        } else {
	            print("Skipping non-TIFF file: " + tifFiles[i]);
	        }
	    }
	
	    if (filesToConcatenate.length > 0) {
	        var ConcatTifFileName;
	
	        if (numBatches == 1) {
	            ConcatTifFileName = "cam_crop.tif";  // nom final direct si un seul batch
	        } else {
	            ConcatTifFileName = "cam_crop_" + batchIndex + ".tif";
	            intermediateFiles = Array.concat(intermediateFiles, ConcatTifFileName);
	        }
	
	        var fullPathTiff = saveCamConcatImDir + File.separator + ConcatTifFileName;
	
	        concatenateTiffFiles(filesToConcatenate);
	        saveAs("Tiff", fullPathTiff);
	        run("Close All");
	        batchIndex++;
	    }
	}
	
	// Concaténation finale uniquement si plusieurs batches
	if (numBatches > 1) {
	    for (var k = 0; k < intermediateFiles.length; k++) {
	        var filePath = saveCamConcatImDir + File.separator + intermediateFiles[k];
	        print("Open file to concatenate : " + filePath);
	        open(filePath);
	        finalFilesToConcat = Array.concat(finalFilesToConcat, getTitle());
	    }
	
	    if (finalFilesToConcat.length > 1) {
	        concatenateTiffFiles(finalFilesToConcat);
	        saveAs("Tiff", finalConcatName);
	        run("Close All");
	        print("Concaténation finale terminée : " + finalConcatName);
	
	        // Suppression des fichiers intermédiaires
	        for (var d = 0; d < intermediateFiles.length; d++) {
	            File.delete(saveCamConcatImDir + File.separator + intermediateFiles[d]);
	        }
	        print("Fichiers intermédiaires supprimés.");
	    }
	}
}

	       
// Fonction pour concaténer plusieurs fichiers TIFF
function concatenateTiffFiles(tiffFiles) {
    var command = "title=Concatenated image";
    for (var i = 0; i < tiffFiles.length; i++) {
        command += " image" + (i + 1) + "=[" + tiffFiles[i] + "]";
    }
    run("Concatenate...", command);
}

// Fonction pour ajouter des tranches vides pour que la taille de la pile soit un multiple de dix
function addSlicesToMakeMultipleOfTen() {
    var stackSize = nSlices;
    var slicesToAdd = (10 - (stackSize % 10)) % 10;
    for (var i = 0; i < slicesToAdd; i++) {
        run("Add Slice");
    }
}

// Fonction pour extraire les chiffres d'une chaîne et retourner un tableau
function extract_digits(a) {
    var arr2 = newArray(); // Tableau de retour contenant les nombres extraits
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

// Fonction pour créer des répertoires s'ils n'existent pas
function createDirectory(path) {
    if (!File.isDirectory(path)) {
        var rc = File.makeDirectory(path);
        if (rc) {
            print("Répertoire créé : " + path);
        } else {
            print("Erreur lors de la création du répertoire : " + path);
        }
    }
}

// Redimensionne une stack en gardant le ratio, pour une hauteur donnée
function resizeStackToHeight(imgTitle, desiredH) {
    // Sélection de la fenêtre
    selectWindow(imgTitle);
    
    // Nombre de slices de la stack
    n = nSlices;
    
    // Dimensions actuelles
    origW = getWidth();
    origH = getHeight();
    
    // Facteur d'échelle
    scale = desiredH / origH;
    
    // Nouvelle largeur (arrondie)
    newW = floor(origW * scale + 0.5);
    
    // Redimensionnement
    run("Size...",
        "width=" + newW +
        " height=" + desiredH +
        " depth=" + n +
        " constrain average interpolation=Bilinear"
    );
}


