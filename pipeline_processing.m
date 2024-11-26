%% If you want to preprocess Jure's data (.npy files)

clearvars
initial_folder = '\\10.51.106.5\data\Data\jm\'; % folders where data are (this must end by animal id)
destinationFolder = 'D:/imaging/jm/'; 

dataFolders = select_folders(initial_folder);

[statPaths, FPaths, iscellPaths, opsPaths, canceledIndices] = find_npy_folders(dataFolders); % find folders with files required for analysis

[newFPaths, newStatPaths, newIscellPaths, newOpsPaths, truedataFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, opsPaths, destinationFolder); % copy npy files in a destination folder

%% If you want to preporcess Leo data's (Fall.mat files)

clearvars
initial_folder = 'D:\imaging\FCD'; % folders where data are (this must end by animal id)

% If data are yet organized, skip this part
% dataFolders = select_folders(initial_folder);
%[truedataFolders] = organize_data_by_animal(dataFolders);

% Starting folder for selection
dataFolders = select_folders(initial_folder);
[truedataFolders, canceledIndices] = find_Fall_folders(dataFolders);


%%

animal_date_list = create_animal_date_list(dataFolders);
% Assign ages to the animals
%animal_date_list = assign_age_to_animal(animal_date_list);

%%
PathSave = 'D:\after_processing';
process_data(PathSave, animal_date_list, truedataFolders); % newFPaths, newStatPaths, newIscellPaths, newOpsPaths)
