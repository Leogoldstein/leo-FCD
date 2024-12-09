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

var PathSave = "D:/after_processing/";

// Sélectionner le répertoire source
var dir = getDirectory("Choose Source Directory ");
var list = getFileList(dir);
setBatchMode(true);

// Parcourir chaque dossier ou fichier dans la liste
for (var i = 0; i < list.length; i++) {
    showProgress(i + 1, list.length);
    var filename = dir + list[i];
    print("Traitement du fichier : " + filename);
    
    // Récupérer le nom du fichier
    var name = File.getName(filename);
         
    if (name.startsWith("mTor")) {
        // Récupérer la liste des sous-dossiers
        var subDirList = getFileList(filename);
    
        // Extraire le nom de base pour "mTor"
        var mTorName = name; // Si nécessaire, nettoyez ou modifiez ce nom
        var mTorDir = PathSave + "FCD/" + mTorName + '/';
            createDirectory(mTorDir);
    
        for (var j = 0; j < subDirList.length; j++) {    
            print("Vérification du sous-dossier : " + subDirList[j]);
            var subDir = filename + "/" + subDirList[j];
 
            var aniDir = mTorDir + subDirList[j];
            createDirectory(aniDir);

            if (File.isDirectory(subDir)) {
                var subSubDirList = getFileList(subDir);
                
                if (subSubDirList.length > 0) {
                    for (var k = 0; k < subSubDirList.length; k++) {
                        // Vérification de l'existence de l'élément avant d'y accéder
                        var subSubDir = subDir + subSubDirList[k];
                        print("Sous-dossier trouvé : " + subSubDir);
                        
                        var saveDir = aniDir + subSubDirList[k];
                        createDirectory(saveDir);
                        
                        var aviFileName = "AVG_concat.avi";  // Nom du fichier AVI à enregistrer
                        var fullPathAvi = saveDir + aviFileName;

                        // Vérifier si le fichier AVI existe déjà
                        if (File.exists(fullPathAvi)) {
                            print("Le fichier AVI existe déjà : " + fullPathAvi);
                            continue; // Passer à l'itération suivante sans faire de calculs supplémentaires
                        }

                        var tseriesFoldersList = getFileList(subSubDir);
                        var tseriesFolders = newArray();
                        var tseriesFolderFound = false;
    
                        for (var l = 0; l < tseriesFoldersList.length; l++) {
                            if (startsWith(tseriesFoldersList[l], "TSeries") && File.isDirectory(subSubDir + "/" + tseriesFoldersList[l])) {
                                tseriesFolderFound = true;
                                tseriesFolders = Array.concat(tseriesFolders, subSubDir + "/" + tseriesFoldersList[l]);
                            }
                        }
    
                        if (!tseriesFolderFound) {
                            print("No 'TSeries' folder found in '" + subSubDir + "'. Skipping this subSubDir.");
                            continue; // Passer au subSubDir suivant
                        }
    
                        // Itérer sur les dossiers 'TSeries'
                        for (tseriesFolderIndex = 0; tseriesFolderIndex < tseriesFolders.length; tseriesFolderIndex++) {
                            tseriesFolder = tseriesFolders[tseriesFolderIndex];
                            print("TSeries folder found: " + tseriesFolder);
                            

                            // Vérifier si le sous-dossier 'suite2p' existe
                            suite2pFolder = tseriesFolder + "/suite2p/";                            
                            if (!File.isDirectory(suite2pFolder)) {
                                print("Skipping " + tseriesFolder + ": No 'suite2p' subfolder found.");
                                continue; 
                            }
                            
                            // Lister les dossiers 'plane' dans suite2pFolder
                            planeFolders = getFileList(suite2pFolder);
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
                                planeFolder = validPlaneFolders[planeFolderIndex];
                                
                                // Vérifier si le dossier 'reg_tif' existe dans le dossier plane
                                regTifFolder = planeFolder + "/reg_tif/";
                                if (File.isDirectory(regTifFolder)) {
                                    tifFiles = getFileList(regTifFolder);
                                    arr_num = extract_digits(tifFiles);
                                    Array.sort(arr_num, tifFiles);	                    

                                    var filesToConcatenate = newArray();
                                    var hasTifFiles = false;

                                    for (var n = 0; n < tifFiles.length; n++) {
                                        file = regTifFolder + "/" + tifFiles[n];
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
                }
            }
        }
    }
}

setBatchMode(false);
