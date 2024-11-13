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

// Fonction pour créer des répertoires s'ils n'existent pas
function createDirectory(path) {
    if (!File.isDirectory(path)) {
        var rc = File.makeDirectory(path);
        if (rc) {
            print("Créé le répertoire : " + path);
        //} else {
        //    print("Erreur lors de la création du répertoire : " + path);
        }
    }
}

// Chemin de sauvegarde
var PathSave = "D:/after_processing/Single Images/";
var dir = getDirectory("Choose Source Directory ");
var list = getFileList(dir);
setBatchMode(true);

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

    var SubFolders = getFileList(filename);
    for (var j = 0; j < SubFolders.length; j++) {
        if (startsWith(SubFolders[j], "SingleImage") && File.isDirectory(filename + SubFolders[j])) {
            var SingleImageFolder = filename + SubFolders[j] + "/";
            var tifFiles = getFileList(SingleImageFolder);
            for (var k = 0; k < tifFiles.length; k++) {
                if (endsWith(tifFiles[k], ".ome.tif")) {
                    var tifFilePath = SingleImageFolder + tifFiles[k];
                    processTifFile(tifFilePath, saveDir);
                }
            }
        } else {
            print("No SingleImages found in " + dir + ".");
        }
    }
}
