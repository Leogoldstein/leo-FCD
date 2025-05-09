function create_ppt_from_figs(selected_groups, daytime)

    import mlreportgen.ppt.*;

    % Extraire les types d’animaux uniques
    animal_types_in_selection = unique(cellfun(@char, {selected_groups.animal_type}, 'UniformOutput', false));
    animal_types_str = strjoin(animal_types_in_selection, '_');
    
    % Construire le nom du fichier
    pptFileName = fullfile('D:\Imaging\Outputs\Presentations', ...
        sprintf('AnalysisFigures_%s_%s.pptx', animal_types_str, daytime));

    
    % Créer présentation
    ppt = Presentation(pptFileName);
    open(ppt);
    
    % Diapositive d'accueil
    slide = add(ppt, 'Title Slide');
    replace(slide, 'Title', 'Analysis Results');
    replace(slide, 'Subtitle', 'Generated by MATLAB');

    boxplots = corr_groups_boxplots_all(selected_groups);
    barplots = barplots_by_type(selected_groups);

    for k = 1:length(selected_groups)

        % Infos groupe courant
        current_animal_group = selected_groups(k).animal_group;
        current_ani_path_group = selected_groups(k).path;
        current_ages_group = selected_groups(k).ages;
        current_env_group = selected_groups(k).env;
        current_type = selected_groups(k).animal_type;
        gcamp_output_folders = selected_groups(k).gcamp_output_folders;
        
        % Slide titre type
        is_first_of_type = (k == 1) || ...
            ~strcmp(selected_groups(k-1).animal_type, current_type);
    
        if is_first_of_type
            slide = add(ppt, 'Title Slide');
            replace(slide, 'Title', current_type);
        end
       
        slide = add(ppt, 'Title Slide');
        replace(slide, 'Title', current_animal_group);

        % Recording 
        
        [~, all_optical_zoom, all_depth, ~] = ...
            find_recording_infos(gcamp_output_folders, current_env_group);

        DF_group = selected_groups(k).gcamp_data.DF;
        paramTable = createAnimalParametersTable(current_ages_group, all_depth, all_optical_zoom, DF_group);

         % Ajout des tableaux et figures locales
        addTableSlide(ppt, sprintf('Animal Parameters of %s', current_animal_group), paramTable);
        addFiguresFromFolder(ppt, current_ani_path_group);
        for path_idx = 1:length(gcamp_output_folders)
            addFiguresFromMeanFolder(ppt, gcamp_output_folders{path_idx});
        end
        

        % Acitivity 

        sampling_rate_group = selected_groups(k).gcamp_data.sampling_rate;
        Raster_group = selected_groups(k).gcamp_data.Raster;
        MAct_group = selected_groups(k).gcamp_data.MAct;

        [NCell_all, mean_frequency_per_minute_all, ~, ~] = ...
            basic_metrics(DF_group, Raster_group, MAct_group, gcamp_output_folders, sampling_rate_group);

        Race_group = selected_groups(k).gcamp_data.Race;
        TRace_group = selected_groups(k).gcamp_data.TRace;
        sce_n_cells_threshold_group = selected_groups(k).gcamp_data.sce_n_cells_threshold;
        sces_distances_group = selected_groups(k).gcamp_data.sces_distances;
    
        [all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, ...
         all_prop_active_cell_SCEs, all_avg_duration_ms] = ...
         SCEs_analysis(TRace_group, sampling_rate_group, Race_group, Raster_group, ...
                       sces_distances_group, gcamp_output_folders);
        
        % Vérifier si c’est le dernier groupe de ce type
        is_last_of_type = (k == length(selected_groups)) || ...
                          ~strcmp(selected_groups(k+1).animal_type, current_type);

        paramTable1 = createMeasuresTable(current_ages_group,  NCell_all, mean_frequency_per_minute_all, ...
            sce_n_cells_threshold_group, all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, ...
            all_prop_active_cell_SCEs, all_avg_duration_ms);

        addTableSlide(ppt, sprintf('Activity of the Network of %s', current_animal_group), paramTable1);

        save_summary_figure(ppt, 'boxplots', boxplots, is_last_of_type, current_type);
        save_summary_figure(ppt, 'barplots', barplots, is_last_of_type, current_type);

    end
    
    % Ajouter un résumé des figures à la fin
    if numel(animal_types_in_selection) > 1
        slide = add(ppt, 'Title Slide');
        replace(slide, 'Title', 'Summary of Analysis');
    end
    
    for k = 1:length(selected_groups)
        saveFolder = 'D:\Imaging\Outputs\Presentations\';  
        summaryFiles = dir(fullfile(saveFolder, '*_summary.png'));
        
        for i = 1:length(summaryFiles)
            figFile = fullfile(summaryFiles(i).folder, summaryFiles(i).name);
            
            % Extraire un titre propre à partir du nom de fichier (ex: "jm_boxplot_summary")
            [~, baseName, ~] = fileparts(summaryFiles(i).name);
            titleText = strrep(baseName, '_', ' ');  % "jm boxplot summary"
            
            if numel(animal_types_in_selection) > 1
                slide = add(ppt, 'Title and Content');
                replace(slide, 'Title', titleText);
            
                img = Picture(figFile);
                replace(slide, 'Content', img);
            end
        end
    end
      
    close(ppt);
    fprintf('PowerPoint saved at: %s\n', pptFileName);

    for i = 1:length(summaryFiles)
        figFile = fullfile(summaryFiles(i).folder, summaryFiles(i).name);
        delete(figFile);  % Supprimer chaque fichier
    end

    close(gcf)

end


%%
function paramTable = createAnimalParametersTable(ages, depths, zooms, DF)
    import mlreportgen.ppt.*;

    paramTable = Table();
    paramTable.ColSpecs = repmat(ColSpec('2in'), 1, 4);
    
    headerRow = TableRow();
    headerRow.Style = {Bold(true)};
    append(headerRow, TableEntry(Paragraph('Animal Age')));
    append(headerRow, TableEntry(Paragraph('Depth')));
    append(headerRow, TableEntry(Paragraph('Optical Zoom')));
    append(headerRow, TableEntry(Paragraph('Number of Cells')));
    append(paramTable, headerRow);

    for i = 1:length(ages)
        row = TableRow();
        append(row, TableEntry(Paragraph(string(ages{i}))));
        append(row, TableEntry(Paragraph(string(depths{i}))));
        append(row, TableEntry(Paragraph(string(zooms{i}))));
        append(row, TableEntry(Paragraph(string(size(DF{i}, 1)))));
        append(paramTable, row);
    end
end


function paramTable = createMeasuresTable(ages, NCell_all, mean_freq_all, thresholds, num_sces, freq_sces, mean_active_cells, perc_active_cells, mean_durations)
    import mlreportgen.ppt.*;

    paramTable = Table();
    paramTable.ColSpecs = repmat(ColSpec('1.5in'), 1, 9); % Plus de colonnes = un peu plus étroit
    
    headerRow = TableRow();
    headerRow.Style = {Bold(true)};
    headers = {'Animal Age', 'Active Cells Number', 'Frequency of activity (/min)', 'SCEs Threshold', 'SCEs Number', 'SCEs Frequency (/min)', 'Mean Active Cells SCEs', 'Percentage Active Cells SCEs', 'Mean SCEs Duration (ms)'};
    for i = 1:length(headers)
        append(headerRow, TableEntry(Paragraph(headers{i})));
    end
    append(paramTable, headerRow);

    for i = 1:length(num_sces)
        row = TableRow();
        append(row, TableEntry(Paragraph(string(ages{i}))));
        append(row, TableEntry(Paragraph(string(NCell_all(i)))));
        append(row, TableEntry(Paragraph(string(mean_freq_all(i)))));
        append(row, TableEntry(Paragraph(string(thresholds{i}))));
        append(row, TableEntry(Paragraph(string(num_sces(i)))));
        append(row, TableEntry(Paragraph(string(freq_sces(i)))));
        append(row, TableEntry(Paragraph(string(mean_active_cells(i)))));
        append(row, TableEntry(Paragraph(string(perc_active_cells(i)))));
        append(row, TableEntry(Paragraph(string(mean_durations(i)))));
        append(paramTable, row);
    end
end

function addTableSlide(ppt, titleText, tableContent)
    slide = add(ppt, 'Title and Table');
    replace(slide, 'Title', titleText);
    replace(slide, 'Table', tableContent);
end

function addFiguresFromFolder(ppt, folder_path)
    import mlreportgen.ppt.*;

    png_files = dir(fullfile(folder_path, '*.png'));
    for i = 1:length(png_files)
        figure_path = fullfile(png_files(i).folder, png_files(i).name);
        slide = add(ppt, 'Title and Content');
        [~, name, ~] = fileparts(png_files(i).name);
        name = strrep(name, '_', ' ');

        replace(slide, 'Title', name);
        img = Picture(figure_path);
        replace(slide, 'Content', img);
    end
end


function addFiguresFromMeanFolder(ppt, folder_path)
    import mlreportgen.ppt.*;
    
    png_files = dir(fullfile(folder_path, 'Mean_image*.png'));
    for i = 1:length(png_files)
        figure_path = fullfile(png_files(i).folder, png_files(i).name);
        slide = add(ppt, 'Title and Content');
        [~, name, ~] = fileparts(png_files(i).name);
        name = strrep(name, '_', ' ');

        replace(slide, 'Title', name);
        img = Picture(figure_path);
        replace(slide, 'Content', img);
    end
end


function save_summary_figure(ppt, plot_type, plot_data, is_last_of_type, current_type)
    import mlreportgen.ppt.*;

    % Vérifie que 'plot_type' est soit 'barplots' soit 'boxplots'
    if ~ismember(plot_type, {'barplots', 'boxplots'})
        error('plot_type doit être "barplots" ou "boxplots".');
    end
    
    % Vérifie si la figure existe pour ce type d'animal
    if is_last_of_type && isfield(plot_data, current_type)
        fig = plot_data.(current_type);
    
        % Vérifier si 'fig' est un handle valide
        if ishandle(fig)
            % Définir le chemin de sauvegarde de la figure
            saveFolder = 'D:\Imaging\Outputs\Presentations\';
            figFile = fullfile(saveFolder, sprintf('%s_%s_summary.png', current_type, plot_type));
            
            % Vérifiez si le répertoire existe
            if ~isfolder(saveFolder)
                % Si le répertoire n'existe pas, afficher un message d'erreur
                error('Le répertoire de sauvegarde n''existe pas : %s', saveFolder);
            end
            
            try
                % Sauvegarder la figure dans un fichier PNG
                saveas(fig, figFile);
                disp(['Figure sauvegardée avec succès dans : ' figFile]);
    
                % Ajouter la figure à la diapositive
                slide = add(ppt, 'Title and Content');
                replace(slide, 'Title', [current_type ' Summary']);
    
                % Insérer l'image dans la présentation
                img = Picture(figFile);  % Utilisation du fichier PNG sauvegardé
                replace(slide, 'Content', img);

            catch ME
                % Si la sauvegarde échoue, afficher l'erreur
                fprintf('Erreur lors de la sauvegarde de la figure : %s\n', ME.message);
            end
        else
            fprintf('Error: Invalid figure handle for %s.\n', current_type);
        end
    end
end