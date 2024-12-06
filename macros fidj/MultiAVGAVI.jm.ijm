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
    var arr2 = newArray(); // tableau de retour contenant les nombres extraits
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
            print("Créé le répertoire : " + path);
        } else {
            print("Erreur lors de la création du répertoire : " + path);
        }
    }
}

// Sélectionnez le répertoire source
var dir = getDirectory("Choose Source Directory ");
var list = getFileList(dir);
setBatchMode(true);

// Définir le répertoire de sauvegarde
var PathSave = "D:/after_processing/";

// Parcourir chaque dossier ou fichier dans la liste
for (var i = 0; i < list.length; i++) {
    showProgress(i + 1, list.length);
    var filename = dir + list[i];
    print(filename);
    
    // Récupérer le nom du fichier
    var name = File.getName(filename);
 
	var indexAnimal = name.indexOf("ani");
    if (indexAnimal != -1) {
        // Extraire le nom de l'animal
        var animal = name.substring(indexAnimal);
    }
    // Extraire la date jusqu'au troisième tiret
    var dateEndIndex = name.indexOf("-", 10);
    var date = name.substring(0, dateEndIndex); // "2024-10-21"

     // Vérifier la présence de "mTor" et l'extraire si trouvé
     var mTorIndex = name.indexOf("mTor");
     if (mTorIndex != -1) {
         var mTorEndIndex = name.indexOf("-", mTorIndex);
         var mTorName = name.substring(mTorIndex, mTorEndIndex);
         var baseDir = PathSave + "FCD/" + mTorName + "/" ;
         createDirectory(baseDir);
      } else {
         // Sinon, sauvegarder dans le dossier CTRL
         var baseDir = PathSave + "CTRL/" ;
      }
    
    var animalDir = baseDir + animal + "/";
    createDirectory(animalDir);
   
    // Créer le répertoire de sauvegarde pour l'animal et la date
    var saveDir = animalDir + date + "/";
    createDirectory(saveDir);

    // Afficher les résultats
    print("Date : " + date);
    print("Animal : " + animal);
    print("Dossier de sauvegarde : " + saveDir);

    // Lister le contenu du dossier actuel
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
    
    // Itérer sur les dossiers 'TSeries'
    for (tseriesFolderIndex = 0; tseriesFolderIndex < tseriesFolders.length; tseriesFolderIndex++) {
        tseriesFolder = tseriesFolders[tseriesFolderIndex];
        print(tseriesFolder);
        
        // Vérifier si le sous-dossier 'suite2p' existe
        suite2pFolder = tseriesFolder + "suite2p/";
        
        if (!File.isDirectory(suite2pFolder)) {
            print("Skipping " + tseriesFolder + ": No 'suite2p' subfolder found.");
            continue; 
        }
        
        // Lister les dossiers 'plane' dans suite2pFolder
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
        
        // Itérer sur les dossiers 'plane'
        for (var planeFolderIndex = 0; planeFolderIndex < validPlaneFolders.length; planeFolderIndex++) {
            planeFolder = validPlaneFolders[planeFolderIndex];
            
            // Vérifier si le dossier 'reg_tif' existe dans le dossier plane
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
                    // print("Opening file: " + file);
                    
                    // Ajouter des tranches vides pour faire en sorte que la taille de la pile soit un multiple de dix
                    addSlicesToMakeMultipleOfTen();
                    
                    filesToConcatenate = Array.concat(filesToConcatenate, getTitle());
                    hasTifFiles = true;
                }
                
                // Concaténer les piles
                if (hasTifFiles) {
                    concatenateTiffFiles(filesToConcatenate);
                    
                    // Appliquer une projection Z groupée
                    run("Grouped Z Project...", "projection=[Average Intensity] group=10");
		    		run("Time Stamper", "starting=0 interval=0.2987373388 x=15 y=15 font=12 '00 decimal=0 or=sec");
		    		run("Animation Options...", "speed=30 first=1 last=" + nSlices);

                    // Sauvegarder l'image concaténée au format TIFF
                    var tiffFileName = "AVG_concat.tif";
                    fullPathTiff = regTifFolder + tiffFileName;
                    saveAs("Tiff", fullPathTiff);
                    
                    // Sauvegarder au format AVI dans le nouveau répertoire
                    var aviFileName = "AVG_concat.avi";
                    fullPathAvi = saveDir + aviFileName;
                    saveAs("AVI", fullPathAvi);
                    
                    print("Saved AVI file: " + fullPathAvi);
                    
                    // Fermer toutes les images
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
