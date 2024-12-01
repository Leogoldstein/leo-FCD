
%% Preprocessing

[truedataFolders, animal_date_list, F, DF, ops, stat, iscell] = pipeline_for_data_preprocessing();

%% Preprocessing and analysis

PathSave = 'D:\after_processing';
process_data(PathSave, animal_date_list, truedataFolders, newFPaths, newStatPaths, newIscellPaths, newOpsPaths);
