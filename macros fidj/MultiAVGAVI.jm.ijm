// Fonction pour gérer les images dans "SingleImage"
function handleSingleImages(subDir, saveSingleImDir) {
    var SubFolders = getFileList(subDir);
    for (var m = 0; m < SubFolders.length; m++) {
        if (startsWith(SubFolders[m], "SingleImage") && File.isDirectory(subDir + "/" + SubFolders[m])) {
            var SingleImageFolder = subDir + "/" + SubFolders[m] + "/";
            var tifFiles = getFileList(SingleImageFolder);
            for (var n = 0; n < tifFiles.length; n++) {
                if (endsWith(tifFiles[n], ".ome.tif")) {
                    var tifFilePath = SingleImageFolder + tifFiles[n];
                    print("tifFilePath : " + tifFilePath);
                    processTifFile(tifFilePath, saveSingleImDir);
                }
            }
        } else {
            print("No SingleImages found in " + SubFolders[m] + ".");
        }
    }
}

// Fonction pour gérer les TSeries et l'AVI enregistré
function handleTSeriesAndAvi(subDir, saveRegisVidDir) {
    var aviFileName = "AVG_concat.avi";  // Nom du fichier AVI à enregistrer
    var fullPathAvi = saveRegisVidDir + aviFileName;

    // Vérifier si le fichier AVI existe déjà
    if (File.exists(fullPathAvi)) {
        print("Le fichier AVI existe déjà : " + fullPathAvi);
        return; // Passer à l'itération suivante sans faire de calculs supplémentaires                           
    }

    var tseriesFoldersList = getFileList(subDir);
    var tseriesFolders = newArray();
    var tseriesFolderFound = false;

    for (var l = 0; l < tseriesFoldersList.length; l++) {
        if (startsWith(tseriesFoldersList[l], "TSeries") && File.isDirectory(subDir + "/" + tseriesFoldersList[l])) {
            tseriesFolderFound = true;
            tseriesFolders = Array.concat(tseriesFolders, subDir + "/" + tseriesFoldersList[l]);
        }
    }

    if (!tseriesFolderFound) {
        print("No 'TSeries' folder found in '" + subDir + "'. Skipping this subDir.");
        return;
    }

    // Itérer sur les dossiers 'TSeries'
    for (var tseriesFolderIndex = 0; tseriesFolderIndex < tseriesFolders.length; tseriesFolderIndex++) {
        var tseriesFolder = tseriesFolders[tseriesFolderIndex];
        print("TSeries folder found: " + tseriesFolder);

        // Vérifier si le sous-dossier 'suite2p' existe
        var suite2pFolder = tseriesFolder + "/suite2p/";                            
        if (!File.isDirectory(suite2pFolder)) {
            print("Skipping " + tseriesFolder + ": No 'suite2p' subfolder found.");
            continue; 
        }

        // Lister les dossiers 'plane' dans suite2pFolder
        var planeFolders = getFileList(suite2pFolder);
        var validPlaneFolders = newArray();

        for (var m = 0; m < planeFolders.length; m++) {
            if (startsWith(planeFolders[m], "plane") && File.isDirectory(suite2pFolder + "/" + planeFolders[m])) {
                validPlaneFolders = Array.concat(validPlaneFolders, suite2pFolder + "/" + planeFolders[m] + "/");
            }
        }

        if (validPlaneFolders.length == 0) {
            print("Skipping " + suite2pFolder + ": No 'plane' folders found.");
            continue;
        }

        // Itérer sur les dossiers 'plane'
        for (var planeFolderIndex = 0; planeFolderIndex < validPlaneFolders.length; planeFolderIndex++) {
            var planeFolder = validPlaneFolders[planeFolderIndex];

            // Vérifier si le dossier 'reg_tif' existe dans le dossier plane
            var regTifFolder = planeFolder + "/reg_tif/";
            if (File.isDirectory(regTifFolder)) {
                var tifFiles = getFileList(regTifFolder);
                var arr_num = extract_digits(tifFiles);
                Array.sort(arr_num, tifFiles);

                var filesToConcatenate = newArray();
                var hasTifFiles = false;

                for (var n = 0; n < tifFiles.length; n++) {
                    var file = regTifFolder + "/" + tifFiles[n];
                    open(file);

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

                    // Sauvegarder les résultats
                    saveAs("AVI", fullPathAvi);
                    print("Saved AVI file: " + fullPathAvi);

                    // Fermer toutes les images
                    run("Close All");
                } else {
                    print("Aucun fichier .tif trouvé dans " + regTifFolder);
                }
            } else {
                print("Aucun dossier 'reg_tif' trouvé dans " + planeFolder);
            }
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

// Fonction pour traiter un fichier TIFF
function processTifFile(tifFilePath, saveDir) {
    var tifFileName = File.getName(tifFilePath);
    var pattern = "(.*)_(.*)_(.*)_(.*)\\.ome.tif";
    
    if (matches(tifFileName, pattern)) {
        var values = split(tifFileName, "_");
        var channel = values[2];
        
        if (channel == "Ch2") {
            open(tifFilePath);
            run("Green");
            saveAs("Jpeg", saveDir + "/" + tifFileName);
        } else if (channel == "Ch1") {
            open(tifFilePath);
            run("Red");
            saveAs("Jpeg", saveDir + "/" + tifFileName);
        } else {
            print("No specific filter for channel: " + channel);
        }
    } else {
        print("Filename does not match the expected pattern: " + tifFileName);
    }
}


// Main logic pour gérer les sous-dossiers en fonction de 'name'
var PathSave = "D:/after_processing/";
var dir = getDirectory("Choose Source Directory ");
var list = getFileList(dir);
setBatchMode(true);

for (var i = 0; i < list.length; i++) {
    var filename = dir + list[i];
    print("Traitement du fichier : " + filename);
    
    var name = File.getName(filename);
    
    var parentFolder = File.getParent(filename); 
    var type = parentFolder.substring(parentFolder.lastIndexOf("\\") + 1);
    
    var subDirList = getFileList(filename);
    var rootDir = PathSave + type + '/' + name + '/';
    createDirectory(rootDir);
    
    // Pour chaque élément de subDirList
    for (var j = 0; j < subDirList.length; j++) {
        var subDir = filename + "/" + subDirList[j];
        
        // Si le nom commence par "mTor", traitement des sous-dossiers niveau 2
        if (name.startsWith("mTor")) {
            var aniDir = rootDir + subDirList[j];
            createDirectory(aniDir);

            if (File.isDirectory(subDir)) {
                var subSubDirList = getFileList(subDir);
                
                if (subSubDirList.length > 0) {
                    for (var k = 0; k < subSubDirList.length; k++) {
                        var subSubDir = subDir + "/" + subSubDirList[k];
                        print("Sous-dossier trouvé : " + subSubDir); 

                        var saveDir = aniDir + "/" + subSubDirList[k];
                        createDirectory(saveDir);
                        
                        var saveSingleImDir = saveDir + "/Single images/";
                        createDirectory(saveSingleImDir);
                        
                        var saveRegisVidDir = saveDir + "/Registered AVI/";
                        createDirectory(saveRegisVidDir);
                    
                        // Traiter les dossiers "SingleImage" dans subSubDir
                        handleSingleImages(subSubDir, saveSingleImDir);
                        
                        // Vérifier et créer l'AVI enregistré
                        handleTSeriesAndAvi(subSubDir, saveRegisVidDir);
                    }
                }
            }    
        }
        
        // Si le nom commence par "ani", traitement des sous-dossiers niveau 1
        else if (name.startsWith("an")) {
            var saveDir = rootDir + subDirList[j];
            createDirectory(saveDir);
        
            var saveSingleImDir = saveDir + "/Single images/";
            createDirectory(saveSingleImDir);
        
            var saveRegisVidDir = saveDir + "/Registered AVI/";
            createDirectory(saveRegisVidDir);
        
            // Traiter les dossiers "SingleImage" dans subDir
            handleSingleImages(subDir, saveSingleImDir);
            
            // Vérifier et créer l'AVI enregistré
            handleTSeriesAndAvi(subDir, saveRegisVidDir);
        }
    }
}

setBatchMode(false);

