function [F0, noise_est, valid_cells, DF_sg, DF_raw, Raster, ...
          Acttmp2, MAct, thresholds, focus_segs, opts, ...
          has_new_outputs, selected_signal, ...
          selection_summary, ...
          isort1_plane, isort2_plane, Sm_plane] = ...
    peak_detection_tuner( ...
        type, ...
        line, ...
        animal, ...
        date, ...
        age, ...
        plane, ...
        F, ...
        fs_plane, ...
        fs_motion, ...
        synchronous_frames, ...
        viewer_mode, ...
        DF_sg, ...
        DF_raw, ...
        F0, ...
        noise_est, ...
        Acttmp2, ...
        Raster, ...
        thresholds, ...
        valid_cells, ...
        cell_type, ...
        ops, ...
        suite2p_path, ...
        iscell_idx, ...
        stat, ...
        masks, ...
        outlines_x, ...
        outlines_y, ...
        electroporated_indices, ...
        meanImg, ...
        gcamp_TSeries_path, ...
        camera_folder, ...
        behavior_frame_limit, ...
        deviation, ...
        bad_frames, ...
        focus_segs, ...
        motion_energy, ...
        speed_active, ...
        metadata, ...
        gcamp_output_folder, ...
        output_folder, ...
        selection_summary_saved, ...
        comment_saved, ...
        isort1_saved, ...
        isort2_saved, ...
        Sm_saved, ...
        recording_keep_saved)

    %==============================================================
    % Options
    %==============================================================

    opts = struct( ...
        'window_size_s',         120, ...
        'savgol_win_ms',         300, ...
        'savgol_poly',             3, ...
        'refrac_ms',             300, ...
        'prominence_factor',       1, ...
        'min_n_peaks_cutoff',     10, ...
        'min_mask_um2',           50, ...
        'min_mask_connectivity', 0.80);

    opts = ...
        convert_opts_ms_to_frames( ...
            opts, ...
            fs_plane);
    
    selection_summary = struct();
    isort1_plane = [];
    isort2_plane = [];
    Sm_plane = [];

    % Les trois indices sont relatifs aux LIGNES du DF deja sauvegarde.
    % L'ordre d'origine est conserve pour toute la duree du Viewer.
    if nargin < 43, isort1_saved = []; end
    if nargin < 44, isort2_saved = []; end
    if nargin < 45, Sm_saved = []; end
    if nargin < 46, recording_keep_saved = []; end

    if nargin < 41 || isempty(selection_summary_saved)
        selection_summary_saved = struct();
    end

    if nargin < 42 || isempty(comment_saved)
        comment_saved = '';
    end

    % En sécurité, si aucun commentaire n'a été fourni explicitement,
    % récupérer celui déjà présent dans le selection_summary sauvegardé.
    if isempty(comment_saved) && ...
            isstruct(selection_summary_saved) && ...
            isfield(selection_summary_saved,'comment') && ...
            ~isempty(selection_summary_saved.comment)

        comment_saved = ...
            selection_summary_saved.comment;
    end

    if isstring(comment_saved)
        comment_saved = char(comment_saved);
    elseif iscell(comment_saved) && ~isempty(comment_saved)
        comment_saved = comment_saved{1};
    end

    if isempty(comment_saved)
        comment_saved = '';
    end

    % Statut propre au PLAN courant : [] = non evalue, 1 = keep, 0 = rejected.
    % Independent de la selection des cellules et des autres plans.
    if isempty(recording_keep_saved) && isstruct(selection_summary_saved) && ...
            isfield(selection_summary_saved,'recording_keep')
        recording_keep_saved = selection_summary_saved.recording_keep;
    end
    recording_keep_saved = normalize_recording_keep(recording_keep_saved);

    %==============================================================
    % PREPROCESSING
    %==============================================================
    
    window_size = ...
        opts.window_size;
    
    % Sauvegarder les indices des cellules retenues AVANT toute
    % reconstruction Viewer.
    valid_cells_saved_input = ...
        valid_cells;
    
    if viewer_mode
    
        nCells_full = ...
            size(F,1);
    
        nFrames_full = ...
            size(F,2);
    
        %==========================================================
        % Indices originaux des cellules conservées
        %==========================================================
    
        viewer_valid_indices = [];
    
        if ~isempty(valid_cells_saved_input)
    
            viewer_valid_indices = ...
                round( ...
                    double( ...
                        valid_cells_saved_input(:)));
    
        elseif isstruct(selection_summary_saved) && ...
            isfield(selection_summary_saved, ...
                    'valid_cells') && ...
            ~isempty(selection_summary_saved.valid_cells)
    
        viewer_valid_indices = ...
            round( ...
                double( ...
                    selection_summary_saved. ...
                    valid_cells(:)));
        end
    
        viewer_valid_indices = ...
            viewer_valid_indices( ...
                isfinite(viewer_valid_indices) & ...
                viewer_valid_indices >= 1 & ...
                viewer_valid_indices <= nCells_full);
    
        viewer_valid_indices = ...
            unique( ...
                viewer_valid_indices, ...
                'stable');
    
        %==========================================================
        % Calcul complet uniquement pour permettre l'affichage
        % des cellules exclues.
        %
        % Les valeurs sauvegardées des cellules conservées seront
        % ensuite remises par-dessus.
        %==========================================================
    
        [DF_raw_full, F0_full] = ...
            F_processing( ...
                F, ...
                bad_frames, ...
                fs_plane, ...
                window_size);
    
        DF_sg_full = ...
            savgol_transform( ...
                DF_raw_full, ...
                opts);
    
        noise_est_full = ...
            estimate_noise( ...
                DF_raw_full);
    
        %==========================================================
        % Remettre DF_sg sauvegardé des cellules conservées
        %==========================================================
    
        if ~isempty(DF_sg)
    
            if size(DF_sg,1) == nCells_full
    
                % Nouveau format éventuel : déjà complet.
                DF_sg_full = ...
                    DF_sg;
    
            elseif ~isempty(viewer_valid_indices) && ...
                    size(DF_sg,1) == numel(viewer_valid_indices)
    
                nFramesCopy = ...
                    min( ...
                        size(DF_sg,2), ...
                        nFrames_full);
    
                DF_sg_full( ...
                    viewer_valid_indices, ...
                    1:nFramesCopy) = ...
                    DF_sg(:,1:nFramesCopy);
            end
        end
    
        %==========================================================
        % Remettre DF_raw sauvegardé
        %==========================================================
    
        if ~isempty(DF_raw)
    
            if size(DF_raw,1) == nCells_full
    
                DF_raw_full = ...
                    DF_raw;
    
            elseif ~isempty(viewer_valid_indices) && ...
                    size(DF_raw,1) == numel(viewer_valid_indices)
    
                nFramesCopy = ...
                    min( ...
                        size(DF_raw,2), ...
                        nFrames_full);
    
                DF_raw_full( ...
                    viewer_valid_indices, ...
                    1:nFramesCopy) = ...
                    DF_raw(:,1:nFramesCopy);
            end
        end
    
        %==========================================================
        % Remettre F0 sauvegardé
        %==========================================================
    
        if ~isempty(F0)
    
            if size(F0,1) == nCells_full
    
                F0_full = ...
                    F0;
    
            elseif ~isempty(viewer_valid_indices) && ...
                    size(F0,1) == numel(viewer_valid_indices)
    
                nFramesCopy = ...
                    min( ...
                        size(F0,2), ...
                        nFrames_full);
    
                F0_full( ...
                    viewer_valid_indices, ...
                    1:nFramesCopy) = ...
                    F0(:,1:nFramesCopy);
            end
        end
    
        %==========================================================
        % Remettre noise sauvegardé
        %==========================================================
    
        if ~isempty(noise_est)
    
            noise_saved = ...
                noise_est(:);
    
            if numel(noise_saved) == nCells_full
    
                noise_est_full = ...
                    noise_saved;
    
            elseif ~isempty(viewer_valid_indices) && ...
                    numel(noise_saved) == numel(viewer_valid_indices)
    
                noise_est_full( ...
                    viewer_valid_indices) = ...
                    noise_saved;
            end
        end
    
        %==========================================================
        % Utiliser maintenant le référentiel COMPLET
        %==========================================================
    
        DF_raw = ...
            DF_raw_full;
    
        DF_sg = ...
            DF_sg_full;
    
        F0 = ...
            F0_full;
    
        noise_est = ...
            noise_est_full;
    
        %==========================================================
        % Quality sur toutes les cellules
        %==========================================================
    
        [ ...
            ~, ...
            SNR, ...
            score, ...
            cells_sorted_by_quality, ...
            ~, ...
            ~, ...
            ~ ...
        ] = ...
            compute_snr_quality( ...
                DF_sg, ...
                noise_est, ...
                opts, ...
                bad_frames);
    
    else
    
        [DF_raw, F0] = ...
            F_processing( ...
                F, ...
                bad_frames, ...
                fs_plane, ...
                window_size);
    
        DF_sg = ...
            savgol_transform( ...
                DF_raw, ...
                opts);
    
        noise_est = ...
            estimate_noise( ...
                DF_raw);
    
        [ ...
            ~, ...
            SNR, ...
            score, ...
            cells_sorted_by_quality, ...
            ~, ...
            ~, ...
            ~ ...
        ] = ...
            compute_snr_quality( ...
                DF_sg, ...
                noise_est, ...
                opts, ...
                bad_frames);
    end
    %==============================================================
    % POPULATIONS
    %
    % F est normalement F_combined.
    %
    % Combined       = toutes les cellules
    % Electroporated = electroporated_indices
    % GCaMP          = complément
    %
    % Aucun recalcul de DF/F0 lors d'un changement de population.
    %==============================================================

    nCells = ...
        size(F,1);

    electroporated_indices = ...
        normalize_electroporated_indices( ...
            electroporated_indices, ...
            nCells);

    if strcmpi(cell_type, 'combined')

        selected_signal = ...
            'combined';

    elseif strcmpi(cell_type, 'electroporated')

        selected_signal = ...
            'electroporated';

    else

        selected_signal = ...
            'gcamp';
    end

    %==============================================================
    % TITRE
    %==============================================================
    
    title_parts = {};
    
    if viewer_mode
    
        title_parts{end+1} = ...
            '[VIEWER MODE]';
    end
    
    title_parts{end+1} = ...
        upper(selected_signal);
    
    if ~isempty(type)
    
        title_parts{end+1} = ...
            char(string(type));
    end
    
    if ~isempty(line)
    
        title_parts{end+1} = ...
            char(string(line));
    end
    
    if ~isempty(animal)
    
        title_parts{end+1} = ...
            char(string(animal));
    end
    
    if ~isempty(date)
    
        title_parts{end+1} = ...
            char(string(date));
    end
    
    if ~isempty(age)
    
        title_parts{end+1} = ...
            char(string(age));
    end
    
    if ~isempty(plane) && ...
            isnumeric(plane) && ...
            isfinite(plane)
    
        title_parts{end+1} = ...
            sprintf( ...
                'Plane %d', ...
                round(plane) - 1);
    end
    
    winTitle = ...
        strjoin( ...
            title_parts, ...
            ' | ');

    %==============================================================
    % GUI
    %==============================================================

    fig = ...
        figure( ...
            'Name', winTitle, ...
            'NumberTitle', 'off', ...
            'Position', [100 100 1300 820], ...
            'Color', [.97 .97 .98]);

    set( ...
        fig, ...
        'KeyPressFcn', ...
        @(~,evnt) navigate_cells(fig, evnt));

    set( ...
        fig, ...
        'CloseRequestFcn', ...
        @(src,~) finalize_and_close( ...
            src, ...
            synchronous_frames));

    ctrl_panel = ...
        uipanel( ...
            'Parent', fig, ...
            'Units', 'normalized', ...
            'Position', [0.01 0.05 0.22 0.92], ...
            'Title', 'Contrôles', ...
            'FontSize', 10, ...
            'Tag', 'ctrl_panel');

    %==============================================================
    % APPDATA GLOBAL
    %==============================================================

    setappdata(fig, 'fs_plane', fs_plane);
    setappdata(fig, 'fs_motion', fs_motion);

    setappdata(fig, 'F_raw', F);

    setappdata(fig, 'DF_sg', DF_sg);
    setappdata(fig, 'DF_raw', DF_raw);
    setappdata(fig, 'F0', F0);

    setappdata(fig, 'noise_est', noise_est);

    setappdata(fig, 'SNR', SNR);
    setappdata(fig, 'score_quality', score);

    setappdata(fig, 'opts', opts);
    setappdata(fig,'suite2p_path',suite2p_path);

    setappdata(fig, 'selected_signal', selected_signal);

    % Tri de PRESENTATION uniquement. Le tri sauvegarde dans les resultats
    % reste celui de raster_processing, independamment de cette option.
    setappdata(fig,'navigation_sort_mode','similarity');

    %==============================================================
    % COMMENTAIRE
    %==============================================================

    setappdata( ...
        fig, ...
        'comment', ...
        comment_saved);

    setappdata( ...
        fig, ...
        'comment_modified', ...
        false);

    setappdata( ...
        fig, ...
        'electroporated_indices', ...
        electroporated_indices);

    setappdata(fig, 'viewer_mode', viewer_mode);

    %==============================================================
    % CONFIRMATION DE LA SÉLECTION
    %
    % false :
    %   fermeture de la fenêtre = aucune nouvelle sortie
    %
    % true :
    %   bouton "Confirmer sélection" utilisé
    %==============================================================
    
    setappdata( ...
        fig, ...
        'selection_confirmed', ...
        false);

    setappdata(fig,'selection_modified',false);
    setappdata(fig,'recording_keep',recording_keep_saved);
    setappdata(fig,'recording_keep_initial',recording_keep_saved);
    setappdata(fig,'recording_keep_modified',false);
    setappdata(fig,'recording_keep_metadata_commit',false);
    setappdata(fig,'confirmation_pending',false);
    setappdata(fig,'recording_keep_prompted_for_confirmation',false);


    % Paramètres de détection modifiés dans le Viewer.
    % Tant que l'utilisateur ne confirme pas, rien n'est sauvegardé.
    setappdata(fig,'detection_params_modified',false);
    setappdata(fig,'viewer_changed_param_fields',{});

    %==============================================================
    % STATUTS DE SÉLECTION
    %
    % manual_status :
    %    0 = aucune décision
    %   +1 = gardée manuellement
    %   -1 = exclue manuellement
    %
    % cutoff_status :
    %    0 = non évaluée
    %   +1 = passe cutoff
    %   -1 = échoue cutoff
    %==============================================================
    
    manual_status_init = ...
        zeros(nCells,1);
    
    cutoff_status_init = ...
        zeros(nCells,1);
    
    if viewer_mode && ...
            isstruct(selection_summary_saved)
    
        %==========================================================
        % Manual
        %==========================================================
    
        if isfield(selection_summary_saved, ...
                'manual_status') && ...
                ~isempty(selection_summary_saved.manual_status)
    
            tmp = ...
                selection_summary_saved.manual_status(:);
    
            if numel(tmp) == nCells
    
                manual_status_init = ...
                    tmp;
            end
        end
    
        %==========================================================
        % Cutoff
        %==========================================================
    
        if isfield(selection_summary_saved, ...
                'cutoff_status') && ...
                ~isempty(selection_summary_saved.cutoff_status)
    
            tmp = ...
                selection_summary_saved.cutoff_status(:);
    
            if numel(tmp) == nCells
    
                cutoff_status_init = ...
                    tmp;
            end
        end
    end
    
    setappdata( ...
        fig, ...
        'manual_status', ...
        manual_status_init);
    
    setappdata( ...
        fig, ...
        'cutoff_status', ...
        cutoff_status_init);
    
    setappdata( ...
        fig, ...
        'selection_summary_saved', ...
        selection_summary_saved);

    %==============================================================
    % QUALITY PERCENTILE
    %==============================================================

    score_quality_percentile = ...
        nan(size(score));

    valid_score = ...
        isfinite(score);

    [~, order_score] = ...
        sort( ...
            score(valid_score), ...
            'ascend');

    tmp = ...
        nan( ...
            sum(valid_score), ...
            1);

    if ~isempty(tmp)

        tmp(order_score) = ...
            linspace( ...
                0, ...
                100, ...
                sum(valid_score));
    end

    score_quality_percentile(valid_score) = ...
        tmp;

    setappdata( ...
        fig, ...
        'score_quality_percentile', ...
        score_quality_percentile);

    %==============================================================
    % AUTRES APPDATA
    %==============================================================

    setappdata(fig, 'motion_energy', motion_energy);
    setappdata(fig, 'speed_active', speed_active);

    setappdata(fig, 'deviation', deviation);
    setappdata(fig, 'bad_frames', bad_frames);
    setappdata(fig, 'focus_segs', focus_segs);

    setappdata( ...
        fig, ...
        'cells_sorted_by_quality', ...
        cells_sorted_by_quality);

    setappdata(fig, 'stat', stat);
    setappdata(fig, 'meanImg', meanImg);
    setappdata(fig, 'metadata', metadata);
    setappdata(fig, 'ops', ops);

    setappdata(fig, 'gcamp_output_folder', gcamp_output_folder);
    setappdata(fig, 'output_folder', output_folder);

    setappdata(fig, 'cell_type', cell_type);

    setappdata( ...
        fig, ...
        'initial_cell_count', ...
        nCells);

    setappdata(fig, 'gcamp_TSeries_path', gcamp_TSeries_path);

    %==============================================================
    % BEHAVIOR MOVIE
    %
    % camera_folder pointe vers le dossier contenant cam_crop.tif.
    % Le TIFF complet n'est jamais charge en RAM : seules les frames
    % demandees sont lues a la volee avec la classe Tiff.
    %
    % motion_energy est deja croppee dans run_gcamp_peak_detection.
    % Quand elle est disponible, sa longueur donne donc directement
    % la derniere frame comportementale autorisee.
    %==============================================================

    behavior_movie_path = '';

    camera_folder_value = ...
        camera_folder;

    while iscell(camera_folder_value)

        if isempty(camera_folder_value)
            camera_folder_value = '';
            break;
        end

        camera_folder_value = ...
            camera_folder_value{1};
    end

    if isstring(camera_folder_value)
        camera_folder_value = char(camera_folder_value);
    end

    if ischar(camera_folder_value) && ...
            ~isempty(camera_folder_value)

        behavior_movie_path = ...
            fullfile( ...
                camera_folder_value, ...
                'cam_crop.tif');
    end

    setappdata( ...
        fig, ...
        'behavior_movie_path', ...
        behavior_movie_path);

    setappdata( ...
        fig, ...
        'behavior_frame_limit', ...
        behavior_frame_limit);

    setappdata(fig, 'type', type);
    setappdata(fig, 'line', line);
    setappdata(fig, 'animal', animal);
    setappdata(fig, 'date', date);
    setappdata(fig, 'age', age);
    setappdata(fig, 'plane', plane);

    setappdata( ...
        fig, ...
        'total_frame_count', ...
        size(F,2));

    setappdata(fig, 'masks', masks);

    setappdata( ...
        fig, ...
        'outlines_x', ...
        outlines_x);
    
    setappdata( ...
        fig, ...
        'outlines_y', ...
        outlines_y);

    %==============================================================
    % VIEWER SAVED DATA
    %
    % En Viewer, reconstruire Raster / Acttmp2 / thresholds dans
    % le référentiel ORIGINAL contenant toutes les cellules.
    %==============================================================
    
    if viewer_mode
    
        nCells_view = ...
            nCells;
    
        nFrames_view = ...
            size(F,2);
    
        valid_cells_tmp = ...
            round( ...
                double( ...
                    valid_cells_saved_input(:)));
        
        if isempty(valid_cells_tmp) && ...
                isstruct(selection_summary_saved) && ...
                isfield(selection_summary_saved,'valid_cells') && ...
                ~isempty(selection_summary_saved.valid_cells)
        
            valid_cells_tmp = ...
                round( ...
                    double( ...
                        selection_summary_saved.valid_cells(:)));
        end
    
        valid_cells_tmp = ...
            valid_cells_tmp( ...
                isfinite(valid_cells_tmp) & ...
                valid_cells_tmp >= 1 & ...
                valid_cells_tmp <= nCells_view);
    
        %==========================================================
        % Acttmp2 complet
        %==========================================================
    
        Acttmp2_view = ...
            cell(nCells_view,1);
    
        %==========================================================
        % Raster complet
        %==========================================================
    
        Raster_view = ...
            false( ...
                nCells_view, ...
                nFrames_view);
    
        %==========================================================
        % Threshold complet
        %==========================================================
    
        thresholds_view = ...
            nan(nCells_view,1);
    
        %==========================================================
        % Remettre les résultats réellement sauvegardés
        %==========================================================
    
        if iscell(Acttmp2)
    
            if numel(Acttmp2) == nCells_view
    
                Acttmp2_view = ...
                    Acttmp2(:);
    
            elseif ~isempty(valid_cells_tmp)
    
                nCopy = ...
                    min( ...
                        numel(valid_cells_tmp), ...
                        numel(Acttmp2));
    
                for ii = 1:nCopy
    
                    Acttmp2_view{ ...
                        valid_cells_tmp(ii)} = ...
                        Acttmp2{ii};
                end
            end
        end
    
        if ~isempty(Raster)
    
            if size(Raster,1) == nCells_view
    
                nFramesCopy = ...
                    min( ...
                        size(Raster,2), ...
                        nFrames_view);
    
                Raster_view(:,1:nFramesCopy) = ...
                    logical( ...
                        Raster(:,1:nFramesCopy));
    
            elseif ~isempty(valid_cells_tmp)
    
                nCopy = ...
                    min( ...
                        numel(valid_cells_tmp), ...
                        size(Raster,1));
    
                nFramesCopy = ...
                    min( ...
                        size(Raster,2), ...
                        nFrames_view);
    
                Raster_view( ...
                    valid_cells_tmp(1:nCopy), ...
                    1:nFramesCopy) = ...
                    logical( ...
                        Raster( ...
                            1:nCopy, ...
                            1:nFramesCopy));
            end
        end
    
        if ~isempty(thresholds)
    
            thresholds_tmp = ...
                thresholds(:);
    
            if numel(thresholds_tmp) == nCells_view
    
                thresholds_view = ...
                    thresholds_tmp;
    
            elseif ~isempty(valid_cells_tmp)
    
                nCopy = ...
                    min( ...
                        numel(valid_cells_tmp), ...
                        numel(thresholds_tmp));
    
                thresholds_view( ...
                    valid_cells_tmp(1:nCopy)) = ...
                    thresholds_tmp(1:nCopy);
            end
        end
    
        %==========================================================
        % Pour les cellules exclues, recalculer uniquement les pics
        % nécessaires à l'AFFICHAGE Viewer.
        %
        % Cela permet notamment de distinguer :
        %   - 0 pics
        %   - pics < cutoff
        %   - exclusion masque/connectivité
        %
        % Cela ne modifie pas les résultats sauvegardés.
        %==========================================================
    
        valid_saved_mask = ...
            false(nCells_view,1);
    
        valid_saved_mask(valid_cells_tmp) = ...
            true;
    
        for cid = 1:nCells_view
    
            if valid_saved_mask(cid)
                continue;
            end
    
            x_detect = ...
                DF_sg(cid,:).';
    
            sigma = ...
                noise_est(cid);
    
            if isempty(x_detect) || ...
                    all(~isfinite(x_detect))
    
                continue;
            end
    
            if ~isfinite(sigma) || ...
                    sigma <= 0
    
                sigma = ...
                    std( ...
                        x_detect, ...
                        'omitnan');
            end
    
            if ~isfinite(sigma) || ...
                    sigma <= 0
    
                sigma = eps;
            end
    
            out = ...
                detect_peaks_cell_core( ...
                    x_detect, ...
                    sigma, ...
                    opts, ...
                    bad_frames);
    
            Acttmp2_view{cid} = ...
                out.locs_raw;
    
            thresholds_view(cid) = ...
                out.threshold;
    
            if ~isempty(out.locs_raw)
    
                Raster_view( ...
                    cid, ...
                    out.locs_raw) = ...
                    true;
            end
        end
    
        setappdata( ...
            fig, ...
            'Raster_saved', ...
            Raster_view);
    
        setappdata( ...
            fig, ...
            'Acttmp2_saved', ...
            Acttmp2_view);
    
        setappdata( ...
            fig, ...
            'thresholds_saved', ...
            thresholds_view);
    
        setappdata( ...
            fig, ...
            'valid_cells_saved', ...
            valid_cells_tmp);
    
    else
    
        setappdata(fig,'Raster_saved',Raster);
        setappdata(fig,'Acttmp2_saved',Acttmp2);
        setappdata(fig,'thresholds_saved',thresholds);
        setappdata(fig,'valid_cells_saved',valid_cells);
    end

    % Viewer : charger la permutation sauvegardee sans la recalculer.
    % Rejet : simple suppression de ligne. Confirmation : nouveau tri.
    if viewer_mode
        initialize_peak_raster_sort(fig,valid_cells_tmp, ...
            isort1_saved,isort2_saved,Sm_saved,true);
    end

    %==============================================================
    % ISCELL DISPLAY
    %==============================================================

    iscell_idx_display = ...
        nan(nCells,1);

    % iscell_idx provient de Suite2p GCaMP : ne pas attribuer cet
    % indice a une cellule electroporee sans correspondance valide.
    if ~isempty(iscell_idx) && ...
            ~strcmpi(cell_type,'electroporated')

        iscell_idx = ...
            iscell_idx(:);

        if strcmpi(cell_type,'combined') && ...
                ~isempty(electroporated_indices)

            is_electroporated = ...
                false(nCells,1);

            is_electroporated( ...
                electroporated_indices) = true;

            gcamp_rows = ...
                find( ...
                    ~is_electroporated);

            n = ...
                min( ...
                    numel(gcamp_rows), ...
                    numel(iscell_idx));

            iscell_idx_display( ...
                gcamp_rows(1:n)) = ...
                iscell_idx(1:n);

        else

            n = ...
                min( ...
                    nCells, ...
                    numel(iscell_idx));

            iscell_idx_display(1:n) = ...
                iscell_idx(1:n);
        end
    end

    setappdata( ...
        fig, ...
        'iscell_idx_display', ...
        iscell_idx_display);

    %==============================================================
    % MASK METRICS
    %==============================================================

    pixel_size_um = NaN;

    mask_sizes = ...
        nan(nCells,1);

    mask_connectivity_ratio = ...
        nan(nCells,1);

    if ~isempty(masks) && ...
            (isnumeric(masks) || islogical(masks)) && ...
            ndims(masks) >= 3

        try

            if isstruct(metadata) && ...
                    isfield(metadata,'PixelSize_um') && ...
                    ~isempty(metadata.PixelSize_um)

                px = ...
                    metadata.PixelSize_um;

                if isnumeric(px)

                    pixel_size_um = ...
                        double(px(1));

                elseif iscell(px) && ...
                        ~isempty(px)

                    pixel_size_um = ...
                        double(px{1});
                end
            end

        catch

            pixel_size_um = NaN;
        end

        nCells_masks = ...
            min( ...
                size(masks,1), ...
                nCells);

        for i = 1:nCells_masks

            current_mask = ...
                squeeze(masks(i,:,:)) > 0;

            if isempty(current_mask) || ...
                    ~any(current_mask(:))

                continue;
            end

            npix = ...
                sum(current_mask(:));

            if isfinite(pixel_size_um) && ...
                    pixel_size_um > 0

                mask_sizes(i) = ...
                    npix * ...
                    pixel_size_um^2;
            end

            CC = ...
                bwconncomp( ...
                    current_mask, ...
                    8);

            if CC.NumObjects > 0

                comp_sizes = ...
                    cellfun( ...
                        @numel, ...
                        CC.PixelIdxList);

                mask_connectivity_ratio(i) = ...
                    max(comp_sizes) / ...
                    sum(comp_sizes);
            end
        end
    end

    setappdata(fig, 'pixel_size_um', pixel_size_um);
    setappdata(fig, 'mask_sizes', mask_sizes);

    setappdata( ...
        fig, ...
        'mask_connectivity_ratio', ...
        mask_connectivity_ratio);

    %==============================================================
    % CALLBACKS
    %==============================================================

    if viewer_mode

        % En Viewer, on ne relance pas le cutoff automatique.
        validate_cb = @(~,~) [];

    else

        validate_cb = ...
            @(~,~) validate_selection_filter(fig);
    end

    % Sélection manuelle autorisée en mode normal ET en Viewer.
    keep_cb = ...
        @(~,~) keep_cell(fig);

    exclude_cb = ...
        @(~,~) exclude_cell(fig);

    % Le bouton de confirmation est distingué d'une simple fermeture
    % de fenêtre afin d'éviter toute sauvegarde accidentelle.
    finalize_cb = ...
        @(~,~) confirm_selection_and_close( ...
            fig, ...
            synchronous_frames);

    %==============================================================
    % NAVIGATION
    %==============================================================

    % Navigation et identifiants cote a cote dans le panneau de controle.
    % Deux lignes permettent d'afficher les indices sans chevauchement.
    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'text', ...
        'String', sprintf('Navigation cellule\n(1 / %d)', nCells), ...
        'Units', 'normalized', ...
        'Position', [0.05 0.950 0.40 0.043], ...
        'Tag', 'lbl_nav_cell', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', [.97 .97 .98], ...
        'FontSize', 9, ...
        'FontWeight', 'bold');

    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'text', ...
        'String', '', ...
        'Units', 'normalized', ...
        'Position', [0.47 0.950 0.49 0.043], ...
        'Tag', 'lbl_nav_identification', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', [.97 .97 .98], ...
        'FontSize', 9, ...
        'FontWeight', 'bold');

    % Deux cases exclusives, comme pour le choix de population.
    % Par defaut, utiliser le tri par similarite deja calcule (isort1).
    uicontrol( ...
        'Parent',ctrl_panel, ...
        'Style','checkbox', ...
        'String','Selon qualité', ...
        'Units','normalized', ...
        'Position',[0.05 0.913 0.42 0.032], ...
        'Value',0, ...
        'Tag','cb_navigation_quality', ...
        'Callback',@(src,~) select_navigation_sort(fig,src,'quality'));

    uicontrol( ...
        'Parent',ctrl_panel, ...
        'Style','checkbox', ...
        'String','Selon similarité', ...
        'Units','normalized', ...
        'Position',[0.49 0.913 0.48 0.032], ...
        'Value',1, ...
        'Tag','cb_navigation_similarity', ...
        'Callback',@(src,~) select_navigation_sort(fig,src,'similarity'));

    if nCells > 1

        step_small = ...
            1 / (nCells - 1);

        step_big = ...
            min( ...
                1, ...
                10 / (nCells - 1));

    else

        step_small = 1;
        step_big = 1;
    end

    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'slider', ...
        'Min', 1, ...
        'Max', max(1,nCells), ...
        'Value', 1, ...
        'SliderStep', [step_small step_big], ...
        'Units', 'normalized', ...
        'Position', [0.05 0.861 0.90 0.045], ...
        'Tag', 'sldr_nav_cell', ...
        'Callback', ...
        @(src,~) update_current_cell( ...
            fig, ...
            round(get(src,'Value'))));

    %==============================================================
    % POPULATION CHECKBOXES
    %==============================================================

    signal_panel = ...
        uipanel( ...
            'Parent', ctrl_panel, ...
            'Units', 'normalized', ...
            'Position', [0.05 0.775 0.90 0.075], ...
            'Title', 'Population', ...
            'FontSize', 9);

    has_electroporated_population = ...
        ~isempty(electroporated_indices);

    has_gcamp_population = ...
        numel(electroporated_indices) < nCells;

    if strcmpi(cell_type,'combined')

        enable_gcamp = ...
            on_off(has_gcamp_population);

        enable_electroporated = ...
            on_off(has_electroporated_population);

        enable_combined = ...
            'on';

    elseif strcmpi(cell_type,'electroporated')

        enable_gcamp = 'off';
        enable_electroporated = 'on';
        enable_combined = 'off';

    else

        enable_gcamp = 'on';
        enable_electroporated = 'off';
        enable_combined = 'off';
    end

    uicontrol( ...
        'Parent', signal_panel, ...
        'Style', 'checkbox', ...
        'String', 'GCaMP', ...
        'Units', 'normalized', ...
        'Position', [0.02 0.53 0.27 0.43], ...
        'Value', strcmp(selected_signal,'gcamp'), ...
        'Enable', enable_gcamp, ...
        'Tag', 'cb_population_gcamp', ...
        'Callback', ...
        @(src,~) select_population_checkbox( ...
            fig, ...
            src, ...
            'gcamp'));

    uicontrol( ...
        'Parent', signal_panel, ...
        'Style', 'checkbox', ...
        'String', 'Electroporated', ...
        'Units', 'normalized', ...
        'Position', [0.30 0.53 0.40 0.43], ...
        'Value', strcmp(selected_signal,'electroporated'), ...
        'Enable', enable_electroporated, ...
        'Tag', 'cb_population_electroporated', ...
        'Callback', ...
        @(src,~) select_population_checkbox( ...
            fig, ...
            src, ...
            'electroporated'));

    uicontrol( ...
        'Parent', signal_panel, ...
        'Style', 'checkbox', ...
        'String', 'Combined', ...
        'Units', 'normalized', ...
        'Position', [0.70 0.53 0.28 0.43], ...
        'Value', strcmp(selected_signal,'combined'), ...
        'Enable', enable_combined, ...
        'Tag', 'cb_population_combined', ...
        'Callback', ...
        @(src,~) select_population_checkbox( ...
            fig, ...
            src, ...
            'combined'));

    % Option d'AFFICHAGE uniquement : la selection sauvegardee ne change pas.
    % Par defaut la navigation parcourt uniquement les cellules retenues.
    setappdata(fig,'show_rejected_cells',false);
    uicontrol( ...
        'Parent',signal_panel, ...
        'Style','checkbox', ...
        'String','Show rejected cells', ...
        'Units','normalized', ...
        'Position',[0.02 0.03 0.95 0.44], ...
        'Value',0, ...
        'Tag','cb_show_rejected_cells', ...
        'Callback',@(src,~) toggle_show_rejected_cells(fig,src));

    %==============================================================
    % SLIDERS
    %==============================================================

    make_slider( ...
        ctrl_panel, ...
        fig, ...
        'Window size (sec)', ...
        'window_size_s', ...
        1, ...
        300, ...
        opts.window_size_s, ...
        [0.05 0.68 0.90 0.06]);

    make_slider( ...
        ctrl_panel, ...
        fig, ...
        'Prominence', ...
        'prominence_factor', ...
        0, ...
        1, ...
        1, ...
        [0.05 0.57 0.90 0.06]);

    make_slider( ...
        ctrl_panel, ...
        fig, ...
        'Réfractaire (ms)', ...
        'refrac_ms', ...
        0, ...
        5000, ...
        opts.refrac_ms, ...
        [0.05 0.49 0.90 0.06]);

    make_slider( ...
        ctrl_panel, ...
        fig, ...
        'SavGol window (ms)', ...
        'savgol_win_ms', ...
        100, ...
        3000, ...
        opts.savgol_win_ms, ...
        [0.05 0.41 0.90 0.06]);

    %==============================================================
    % REINITIALISER LES PARAMETRES DE DETECTION
    %==============================================================

    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'pushbutton', ...
        'String', 'Réinitialiser paramètres', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.355 0.90 0.04], ...
        'FontWeight', 'bold', ...
        'Tag', 'btn_reset_detection_params', ...
        'Callback', ...
        @(~,~) reset_detection_params(fig));

    %==============================================================
    % COMMENTAIRE
    %==============================================================
    
    comment_panel = ...
        uipanel( ...
            'Parent', ctrl_panel, ...
            'Units', 'normalized', ...
            'Position', [0.05 0.225 0.90 0.115], ...
            'Title', 'Commentaire', ...
            'FontSize', 9, ...
            'Tag', 'comment_panel');
    
    comment_display = ...
        comment_saved;
    
    if isempty(comment_display)
        comment_display = ...
            'Aucun commentaire';
    end
    
    uicontrol( ...
        'Parent', comment_panel, ...
        'Style', 'edit', ...
        'Units', 'normalized', ...
        'Position', [0.03 0.10 0.69 0.80], ...
        'String', comment_display, ...
        'HorizontalAlignment', 'left', ...
        'Max', 10, ...
        'Min', 0, ...
        'Enable', 'inactive', ...
        'BackgroundColor', [1 1 1], ...
        'Tag', 'txt_comment');
    
    uicontrol( ...
        'Parent', comment_panel, ...
        'Style', 'pushbutton', ...
        'String', 'Modifier', ...
        'Units', 'normalized', ...
        'Position', [0.75 0.25 0.22 0.50], ...
        'FontWeight', 'bold', ...
        'Tag', 'btn_edit_comment', ...
        'Callback', ...
        @(~,~) edit_peak_detection_comment(fig));
    
    %==============================================================
    % VOYANT DU PLAN COURANT (et non du statut d'une cellule)
    %==============================================================

    uicontrol('Parent',ctrl_panel,'Style','text', ...
        'String',sprintf('Plan %d :',plane-1),'Units','normalized', ...
        'Position',[0.05 0.121 0.30 0.030], ...
        'HorizontalAlignment','left','FontWeight','bold', ...
        'BackgroundColor',[.97 .97 .98]);
    uicontrol('Parent',ctrl_panel,'Style','text', ...
        'String',char(9679),'Units','normalized', ...
        'Position',[0.34 0.117 0.10 0.038], ...
        'Tag','lbl_recording_led','FontSize',17, ...
        'BackgroundColor',[.97 .97 .98]);
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Keep','TooltipString','Keep recording', ...
        'Units','normalized', ...
        'Position',[0.45 0.114 0.25 0.043], ...
        'Tag','btn_keep_recording', ...
        'Callback',@(~,~) set_recording_keep(fig,1));
    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Reject','TooltipString','Rejected recording', ...
        'Units','normalized', ...
        'Position',[0.71 0.114 0.27 0.043], ...
        'Tag','btn_reject_recording', ...
        'Callback',@(~,~) set_recording_keep(fig,0));
    refresh_recording_keep_indicator(fig);

    %==============================================================
    % BOUTONS
    %==============================================================
    
    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'pushbutton', ...
        'String', 'Garder cellule', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.170 0.42 0.050], ...
        'BackgroundColor', [0.10 0.60 0.10], ...
        'ForegroundColor', 'w', ...
        'FontWeight', 'bold', ...
        'FontSize', 11, ...
        'Callback', keep_cb);
    
    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'pushbutton', ...
        'String', 'Exclure cellule', ...
        'Units', 'normalized', ...
        'Position', [0.53 0.170 0.42 0.050], ...
        'BackgroundColor', [0.80 0.15 0.15], ...
        'ForegroundColor', 'w', ...
        'FontWeight', 'bold', ...
        'FontSize', 11, ...
        'Callback', exclude_cb);
    
    uicontrol( ...
        'Parent', ctrl_panel, ...
        'Style', 'pushbutton', ...
        'String', 'Confirmer sélection', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.025 0.90 0.065], ...
        'BackgroundColor', [0.1 0.6 0.35], ...
        'ForegroundColor', 'w', ...
        'FontWeight', 'bold', ...
        'FontSize', 12, ...
        'Tag', 'btn_confirm_selection', ...
        'Callback', finalize_cb);

    uicontrol('Parent',ctrl_panel,'Style','pushbutton', ...
        'String','Retour avant confirmation','Units','normalized', ...
        'Position',[0.55 0.025 0.40 0.065], ...
        'Tag','btn_undo_confirmation','Visible','off', ...
        'Callback',@(~,~) undo_recording_confirmation(fig));

    if viewer_mode

        % En revanche, les corrections manuelles sont autorisées.
        set( ...
            findobj(ctrl_panel,'String','Garder cellule'), ...
            'Enable','on');

        set( ...
            findobj(ctrl_panel,'String','Exclure cellule'), ...
            'Enable','on');

        % update_population_action_buttons() décidera ensuite si la
        % confirmation est autorisée dans la population affichée.
        set( ...
            findobj(ctrl_panel,'String','Confirmer sélection'), ...
            'Enable','on');

    else

        set( ...
            findobj(ctrl_panel,'String','Reprocess'), ...
            'Enable','off');
    end
    
    update_population_action_buttons(fig);
    
    %==============================================================
    % AXES
    %==============================================================

    % En Viewer : les cinq graphiques temporels partagent exactement
    % les memes abscisses et la meme largeur. A droite de la trace DF,
    % reserver un espace pour l'image moyenne zoomee de la cellule.
    % Ne pas modifier la disposition en mode detection initiale.
    % Meme disposition dans les deux modes : le raster trie est visible
    % des l'application du cutoff, AVANT confirmation d'une detection.
    pos_trace  = [0.28 0.385 0.47 0.215];
    pos_raster = [pos_trace(1) 0.645 pos_trace(3) 0.265];
    pos_f0     = [pos_trace(1) 0.285 pos_trace(3) 0.065];
    pos_motion = [pos_trace(1) 0.195 pos_trace(3) 0.060];
    pos_dev    = [pos_trace(1) 0.105 pos_trace(3) 0.060];

    ax1 = ...
        axes( ...
            'Parent', fig, ...
            'Position', pos_trace);
    
    %==============================================================
    % Un seul temps global partage par la ROI et la camera.
    % Un seul curseur par axe, sans drag-and-drop.
    %==============================================================

    setappdata(fig,'shared_movie_time',0);
    setappdata(fig,'shared_movie_max_time',Inf);
    setappdata(fig,'shared_movie_cursor',[]);
    setappdata(fig,'shared_movie_cursor_f0',[]);
    setappdata(fig,'shared_movie_cursor_dev',[]);
    setappdata(fig,'shared_movie_cursor_motion',[]);
    setappdata(fig,'shared_movie_cursor_raster',[]);

    box(ax1,'on');

    xlabel(ax1,'Time (s)');
    ylabel(ax1,'\DeltaF/F (SavGol)');

    plot(ax1,NaN,NaN,'k-');
    hold(ax1,'on');

    axF0 = ...
        axes( ...
            'Parent', fig, ...
            'Position', pos_f0);

    box(axF0,'on');
    ylabel(axF0,'F0');
    set(axF0,'XTickLabel',[]);
    hold(axF0,'on');

    axDev = ...
        axes( ...
            'Parent', fig, ...
            'Position', pos_dev);

    box(axDev,'on');
    ylabel(axDev,'Dev');
    set(axDev,'XTickLabel',[]);
    hold(axDev,'on');

    axMotion = ...
        axes( ...
            'Parent', fig, ...
            'Position', pos_motion);

    box(axMotion,'on');
    ylabel(axMotion,'Motion');
    set(axMotion,'XTickLabel',[]);
    hold(axMotion,'on');

    % Deviation est maintenant l'axe inferieur : temps affiche ici seul.
    set(axDev,'XTickLabelMode','auto');
    xlabel(axDev,'Time (s)');

    % Raster trie en haut, aussi en nouvelle detection avant confirmation.
    axRaster = axes( ...
        'Parent',fig, ...
        'Units','normalized', ...
        'Position',pos_raster, ...
        'Tag','ax_peak_raster');
    box(axRaster,'on');
    set(axRaster,'XTickLabel',[]);
    ylabel(axRaster,'Cellule (ID)');
    title(axRaster,'Raster des pics du plan');

    % Image moyenne / film ROI : meme emplacement a droite du DF.
    % L'image moyenne est visible au repos, le film ROI prend sa place
    % uniquement pendant la lecture. Aucun axe n'est dans une autre figure.
    % Degager l'espace entre le titre ROI et les boutons au-dessus.
    pos_roi = [0.77 pos_trace(2) 0.20 pos_trace(4)-0.025];
    axROI = axes( ...
        'Parent',fig, ...
        'Units','normalized', ...
        'Position',pos_roi, ...
        'Tag','ax_viewer_mean_roi');
    box(axROI,'on');
    axis(axROI,'image');
    title(axROI,'ROI');
    set(axROI,'XTick',[],'YTick',[]);
    if viewer_mode
        setappdata(fig,'axViewerROI',axROI);
    else
        setappdata(fig,'axViewerROI',[]);
    end
    setappdata(fig,'axROI',axROI);

    % Film comportemental directement sous l'image moyenne.
    % Ne pas relier ces axes image aux axes des traces temporelles.
    pos_behavior = [0.77 0.105 0.20 0.235];
    axBehavior = axes( ...
        'Parent',fig, ...
        'Units','normalized', ...
        'Position',pos_behavior, ...
        'Tag','ax_embedded_behavior');
    axis(axBehavior,'image');
    axis(axBehavior,'off');
    title(axBehavior,'Comportement');
    setappdata(fig,'axBehavior',axBehavior);
    setappdata(fig,'roi_movie_visible',false);

    setappdata(fig,'roi_movie_data',[]);
    setappdata(fig,'roi_movie_timer',[]);
    setappdata(fig,'roi_movie_playing',false);
    setappdata(fig,'roi_movie_frame',1);
    setappdata(fig,'roi_crop_bounds',[]);
    setappdata(fig,'roi_movie_hImg',[]);
    setappdata(fig,'roi_movie_clim',[]);

    setappdata(fig,'behavior_movie_tiff',[]);
    setappdata(fig,'behavior_movie_fid',[]);
    setappdata(fig,'behavior_movie_timer',[]);
    setappdata(fig,'behavior_movie_playing',false);
    setappdata(fig,'behavior_movie_frame',1);
    setappdata(fig,'behavior_movie_hImg',[]);
    setappdata(fig,'behavior_movie_clim',[]);
    setappdata(fig,'behavior_movie_start_frame',1);
    setappdata(fig,'behavior_movie_start_tic',[]);

    setappdata(fig,'ax1',ax1);
    setappdata(fig,'axF0',axF0);
    setappdata(fig,'axDev',axDev);
    setappdata(fig,'axMotion',axMotion);
    setappdata(fig,'axRaster',axRaster);
    setappdata(fig,'hBadPatch_axRaster',[]);
    setappdata(fig,'hCurrentCellRasterArrow',[]);

    % La fleche est une annotation en coordonnees de figure : contrairement
    % aux pics, elle ne suit pas automatiquement les zooms sur les axes.
    % Ecouter leurs limites et leur position pour rester en face de la
    % cellule visible, sans recalculer ni modifier le raster sauvegarde.
    raster_arrow_listeners = [ ...
        addlistener(axRaster,'YLim','PostSet', ...
            @(~,~) update_current_cell_raster_arrow(fig)), ...
        addlistener(axRaster,'XLim','PostSet', ...
            @(~,~) update_current_cell_raster_arrow(fig)), ...
        addlistener(axRaster,'Position','PostSet', ...
            @(~,~) update_current_cell_raster_arrow(fig)), ...
        addlistener(axRaster,'YDir','PostSet', ...
            @(~,~) update_current_cell_raster_arrow(fig))];
    setappdata(fig,'raster_arrow_listeners',raster_arrow_listeners);
    set(fig,'SizeChangedFcn',@(~,~) update_current_cell_raster_arrow(fig));

    roi_movie_available = ...
        ~isempty(suite2p_path) && ...
        isfolder(fullfile(char(string(suite2p_path)),'reg_tif'));

    behavior_movie_available = ...
        ~isempty(behavior_movie_path) && isfile(behavior_movie_path);

    setappdata(fig,'shared_movie_available', ...
        roi_movie_available || behavior_movie_available);

    % speed_active est binaire et indexe en frames GLOBALES.
    % Memoriser le debut ET la derniere frame de chaque episode.
    speed_active_onset_times = [];
    speed_active_end_times = [];

    if ~isempty(speed_active) && ...
            isvector(speed_active) && ...
            (isnumeric(speed_active) || islogical(speed_active)) && ...
            isscalar(fs_motion) && isfinite(fs_motion) && fs_motion > 0

        active = speed_active(:) > 0 & isfinite(speed_active(:));
        onset_frames = find(active & ~[false; active(1:end-1)]);
        end_frames = find(active & ~[active(2:end); false]);
        speed_active_onset_times = (onset_frames - 1) / fs_motion;
        speed_active_end_times = (end_frames - 1) / fs_motion;
    end

    setappdata(fig,'speed_active_onset_times',speed_active_onset_times);
    setappdata(fig,'speed_active_end_times',speed_active_end_times);
    setappdata(fig,'speed_active_stop_time',[]);
    setappdata(fig,'speed_active_last_onset_time',[]);

    % Lecture unique AU-DESSUS de l'image ROI, dans les deux modes.
    % Les fleches positionnent sans lire ; Play respecte la fin de l'episode.
    controls_y = 0.608;
    controls_h = 0.031;
    navigation_enabled = getappdata(fig,'shared_movie_available') && ...
        ~isempty(speed_active_onset_times);

    uicontrol( ...
        'Parent',fig,'Style','pushbutton','String','←', ...
        'Units','normalized', ...
        'Position',[0.786 controls_y 0.046 controls_h], ...
        'FontWeight','bold','FontSize',12, ...
        'Tag','btn_prev_speed_active', ...
        'TooltipString','Debut speed_active precedent (sans lecture)', ...
        'Enable',on_off(navigation_enabled), ...
        'Callback',@(~,~) navigate_speed_active(fig,-1));

    btn_shared_movie = uicontrol( ...
        'Parent',fig,'Style','pushbutton','String','▶', ...
        'Units','normalized', ...
        'Position',[0.847 controls_y 0.046 controls_h], ...
        'FontWeight','bold','FontSize',12, ...
        'Tag','btn_shared_movie', ...
        'TooltipString','Lire / Pause ROI et comportement synchronises', ...
        'Enable',on_off(getappdata(fig,'shared_movie_available')), ...
        'Callback',@(~,~) toggle_shared_movie(fig));

    uicontrol( ...
        'Parent',fig,'Style','pushbutton','String','→', ...
        'Units','normalized', ...
        'Position',[0.908 controls_y 0.046 controls_h], ...
        'FontWeight','bold','FontSize',12, ...
        'Tag','btn_next_speed_active', ...
        'TooltipString','Debut speed_active suivant (sans lecture)', ...
        'Enable',on_off(navigation_enabled), ...
        'Callback',@(~,~) navigate_speed_active(fig,+1));
    setappdata(fig,'btn_shared_movie',btn_shared_movie);

    % Clic sur les courbes : deplacer le curseur + la camera sans lecture.
    set(fig,'WindowButtonDownFcn',@(~,~) click_movie_graph(fig));

    %==============================================================
    % OFFSET TEMPOREL EXACT DU PLAN
    %
    % frame 1 du plan p correspond a la frame globale p.
    %==============================================================

    plane_time_offset = ...
        (plane - 1) / ...
        fs_motion;

    %==============================================================
    % MOTION DISPLAY
    %==============================================================

    dev = ...
        deviation(:).';

    if ~isempty(dev)

        t_dev = ...
            plane_time_offset + ...
            (0:numel(dev)-1) / fs_plane;

        plot(axDev,...
            t_dev,...
            dev,...
            'k-',...
            'HitTest','off');

        dv = ...
            dev(isfinite(dev));

        if ~isempty(dv)

            lo = prctile(dv,2);
            hi = prctile(dv,98);

            if isfinite(lo) && ...
                    isfinite(hi) && ...
                    hi > lo

                pad = ...
                    0.1 * ...
                    (hi - lo);

                ylim( ...
                    axDev, ...
                    [lo-pad hi+pad]);
            end
        end

    else

        text( ...
            axDev, ...
            0.5, ...
            0.5, ...
            'deviation vide', ...
            'Units','normalized', ...
            'HorizontalAlignment','center');
    end

    if ~isempty(motion_energy)

        motion_energy = ...
            motion_energy(:).';

        t_motion = (0:numel(motion_energy)-1) / fs_motion;

        plot(axMotion,...
            t_motion,...
            motion_energy,...
            'k-',...
            'HitTest','off');

    else

        text( ...
            axMotion, ...
            0.5, ...
            0.5, ...
            'motion energy vide', ...
            'Units','normalized', ...
            'HorizontalAlignment','center');
    end

    %==============================================================
    % BAD-FRAME SEGMENTS FOR DISPLAY
    %
    % focus_segs is expressed in PLANE frames.
    % Convert once to seconds because all linked X axes are in time.
    %==============================================================

    focus_segs_time = [];

    if ~isempty(focus_segs)

        focus_segs_time = ...
            double(focus_segs);

        focus_segs_time(:,1) = ...
            plane_time_offset + ...
            (focus_segs_time(:,1) - 1) / fs_plane;

        focus_segs_time(:,2) = ...
            plane_time_offset + ...
            focus_segs_time(:,2) / fs_plane;
    end

    setappdata( ...
        fig, ...
        'focus_segs_time', ...
        focus_segs_time);

    if ~isempty(focus_segs_time)

        hBad1 = ...
            create_badframe_patch( ...
                ax1, ...
                focus_segs_time);

        setappdata(fig,'hBadPatch_ax1',hBad1);

        hBadF0 = ...
            create_badframe_patch( ...
                axF0, ...
                focus_segs_time);

        setappdata(fig,'hBadPatch_axF0',hBadF0);

        hBadDev = ...
            create_badframe_patch( ...
                axDev, ...
                focus_segs_time);

        setappdata(fig,'hBadPatch_axDev',hBadDev);
    end

    linked_axes = [ax1 axF0 axDev axMotion axRaster];
    linkaxes(linked_axes,'x');

    %==============================================================
    % PEAK COUNTS
    %==============================================================
    
    if viewer_mode
    
        n_peaks_all = ...
            zeros(nCells,1);
    
        %==========================================================
        % Utiliser les données RECONSTRUITES dans le référentiel
        % original de toutes les cellules.
        %==========================================================
    
        Acttmp2_viewer = ...
            getappdata( ...
                fig, ...
                'Acttmp2_saved');
    
        Raster_viewer = ...
            getappdata( ...
                fig, ...
                'Raster_saved');
    
        if iscell(Acttmp2_viewer) && ...
                ~isempty(Acttmp2_viewer)
    
            for cid = 1:min(nCells,numel(Acttmp2_viewer))
    
                n_peaks_all(cid) = ...
                    numel( ...
                        Acttmp2_viewer{cid});
            end
    
        elseif ~isempty(Raster_viewer)
    
            n_peaks_tmp = ...
                sum( ...
                    logical(Raster_viewer), ...
                    2);
    
            nCopy = ...
                min( ...
                    nCells, ...
                    numel(n_peaks_tmp));
    
            n_peaks_all(1:nCopy) = ...
                n_peaks_tmp(1:nCopy);
        end
    
        setappdata( ...
            fig, ...
            'n_peaks_all', ...
            n_peaks_all);
    
        setappdata( ...
            fig, ...
            'cutoff_validated', ...
            false);
    
        setappdata( ...
            fig, ...
            'cutoff_locked', ...
            true);
    
    else
    
        recompute_n_peaks_all(fig);
    end

    %==============================================================
    % INITIALISER NAVIGATION
    %==============================================================

    % Appliquer automatiquement le cutoff par défaut
    if ~viewer_mode
        apply_auto_cutoff(fig);
        initial_kept = get_navigation_kept_mask(fig,nCells,false);
        initialize_peak_raster_sort(fig,find(initial_kept),[],[],[],false);
    end

    refresh_selection_order(fig);
    
    if isappdata(fig,'order_cells')
    
        order_cells = ...
            getappdata(fig,'order_cells');
    
        if ~isempty(order_cells)
    
            update_current_cell(fig,1);
        end
    end

    update_population_window_title(fig);

    % Afficher le raster trie apres cutoff aussi avant confirmation.
    % Les indices d'origine et la selection restent independants du tri.
    refresh_peak_raster(fig);

    % Barre temporelle commune visible d'emblee : aucune lecture lancee.
    % La camera affiche sa premiere frame juste apres l'initialisation.
    update_shared_movie_cursor(fig,getappdata(fig,'shared_movie_time'));

    % Afficher immediatement la premiere image comportementale en pause.
    if behavior_movie_available
        if ~show_behavior_movie_frame(fig,1,true)
            cla(axBehavior);
            text(axBehavior,.5,.5,'Impossible de lire cam\_crop.tif', ...
                'Units','normalized','HorizontalAlignment','center');
        end
    else
        text(axBehavior,.5,.5,'cam\_crop.tif indisponible', ...
            'Units','normalized','HorizontalAlignment','center');
    end
    drawnow;

    %==============================================================
    % WAIT
    %==============================================================

    uiwait(fig);

    %==============================================================
    % MODIFICATION DU COMMENTAIRE
    %
    % Indépendante de selection_modified.
    %==============================================================
    
    comment_modified = ...
        ishghandle(fig) && ...
        isappdata(fig,'comment_modified') && ...
        getappdata(fig,'comment_modified');

    %==============================================================
    % SELECTED SIGNAL
    %==============================================================

    if ishghandle(fig) && ...
            isappdata(fig,'selected_signal')

        selected_signal = ...
            char( ...
                string( ...
                    getappdata(fig,'selected_signal')));
    end

    has_new_outputs = false;

    %==============================================================
    % OUTPUTS
    %
    % has_new_outputs concerne UNIQUEMENT les données de détection /
    % sélection.
    %
    % Une modification du commentaire est renvoyée dans
    % selection_summary mais ne met PAS has_new_outputs à true.
    %==============================================================
    
    if ishghandle(fig) && ...
            isappdata(fig,'last_save_outputs')
    
        out = ...
            getappdata(fig,'last_save_outputs');
    
        % Une vraie sélection a été sauvegardée.
        has_new_outputs = true;
    
        valid_cells = ...
            out.valid_cells;
    
        DF_raw = ...
            out.DF_raw;
    
        DF_sg = ...
            out.DF_sg;
    
        F0 = ...
            out.F0;
    
        noise_est = ...
            out.noise_est;
    
        Raster = ...
            out.Raster;
    
        Acttmp2 = ...
            out.Acttmp2;
    
        MAct = ...
            out.MAct;
    
        thresholds = ...
            out.thresholds;

        isort1_plane = out.isort1_plane;
        isort2_plane = out.isort2_plane;
        Sm_plane = out.Sm_plane;

        % Les paramètres modifiés dans l'interface doivent eux aussi
        % être renvoyés à run_gcamp_peak_detection.
        if isfield(out,'opts') && ...
                ~isempty(out.opts)

            opts = ...
                out.opts;
        end
    
        if isfield(out,'summary') && ...
                ~isempty(out.summary)
    
            selection_summary = ...
                out.summary;
    
        else
    
            selection_summary = ...
                struct();
        end
    
    else
    
        %==========================================================
        % AUCUNE MODIFICATION DE SÉLECTION
        %
        % Important :
        % on ne crée PAS de nouveaux outputs de détection.
        %
        % Mais on conserve quand même selection_summary pour pouvoir
        % renvoyer un éventuel nouveau commentaire.
        %==========================================================
    
        has_new_outputs = ...
            false;
    
        Raster = ...
            false(size(F));
    
        Acttmp2 = ...
            repmat( ...
                {[]}, ...
                nCells, ...
                1);
    
        MAct = [];
    
        thresholds = ...
            nan(nCells,1);
    
        valid_cells = [];
    
        DF_sg = [];
        DF_raw = [];
        F0 = [];
        noise_est = [];
    
        %==========================================================
        % Reprendre le summary déjà sauvegardé
        %==========================================================
    
        if isstruct(selection_summary_saved)
    
            selection_summary = ...
                selection_summary_saved;
    
        else
    
            selection_summary = ...
                struct();
        end
    
        %==========================================================
        % Remplacer uniquement le commentaire
        %==========================================================
    
        if ishghandle(fig) && ...
                isappdata(fig,'comment')
    
            selection_summary.comment = ...
                getappdata(fig,'comment');
        end
    end
    
    %==============================================================
    % Signaler séparément si le commentaire a changé
    %
    % CE FLAG NE DOIT PAS servir à modified_plane.
    %==============================================================
    
    selection_summary.comment_modified = ...
        comment_modified;

    committed = (isappdata(fig,'selection_confirmed') && ...
        getappdata(fig,'selection_confirmed')) || ...
        (isappdata(fig,'recording_keep_metadata_commit') && ...
        getappdata(fig,'recording_keep_metadata_commit'));
    if committed
        decision = normalize_recording_keep(getappdata(fig,'recording_keep'));
        % [] signifie reellement "non renseigne" : jamais assimile a 0.
        selection_summary.recording_keep = decision;
        selection_summary.recording_keep_modified = ...
            ~isequal(getappdata(fig,'recording_keep_initial'),decision);
    else
        selection_summary.recording_keep_modified = false;
    end

    if ishghandle(fig)
        delete(fig);
    end
end

%% ===================== POPULATION =====================

function indices = ...
        normalize_electroporated_indices( ...
            indices, ...
            nCells)

    if nargin < 2 || ...
            isempty(nCells) || ...
            ~isfinite(nCells)

        nCells = 0;
    end

    if isempty(indices)

        indices = ...
            zeros(0,1);

        return;
    end

    indices = ...
        round( ...
            double(indices(:)));

    indices = ...
        indices( ...
            isfinite(indices) & ...
            indices >= 1 & ...
            indices <= nCells);

    indices = ...
        unique( ...
            indices, ...
            'stable');
end


function indices = ...
        get_active_population_indices( ...
            fig, ...
            nCells)

    all_indices = ...
        (1:nCells).';

    selected_signal = ...
        'combined';

    if isappdata(fig,'selected_signal')

        selected_signal = ...
            lower( ...
                char( ...
                    string( ...
                        getappdata( ...
                            fig, ...
                            'selected_signal'))));
    end

    electroporated_indices = [];

    if isappdata(fig,'electroporated_indices')

        electroporated_indices = ...
            getappdata( ...
                fig, ...
                'electroporated_indices');
    end

    electroporated_indices = ...
        normalize_electroporated_indices( ...
            electroporated_indices, ...
            nCells);

    switch selected_signal

        case 'combined'

            indices = ...
                all_indices;

        case 'electroporated'

            indices = ...
                electroporated_indices;

        case 'gcamp'

            indices = ...
                setdiff( ...
                    all_indices, ...
                    electroporated_indices, ...
                    'stable');

        otherwise

            indices = ...
                all_indices;
    end
end


function select_population_checkbox( ...
        fig, ...
        src, ...
        selected_signal)

    if ~ishghandle(fig)
        return;
    end

    % Impossible d'avoir zéro case cochée.
    if get(src,'Value') == 0

        set(src,'Value',1);
        return;
    end

    tags = { ...
        'cb_population_gcamp', ...
        'cb_population_electroporated', ...
        'cb_population_combined'};

    for k = 1:numel(tags)

        h = ...
            findobj( ...
                fig, ...
                'Tag', ...
                tags{k});

        if isempty(h)
            continue;
        end

        if h ~= src

            set( ...
                h, ...
                'Value', ...
                0);
        end
    end

    %==========================================================
    % SEULEMENT changement d'affichage.
    %
    % manual_status et cutoff_status NE SONT PAS touchés.
    %
    % C'est ce qui assure la propagation :
    %
    % combined <-> GCaMP <-> Electroporated
    %==========================================================

    setappdata( ...
        fig, ...
        'selected_signal', ...
        selected_signal);
    
    update_population_action_buttons(fig);

    update_population_window_title(fig);

    refresh_selection_order(fig);

    if isappdata(fig,'order_cells')

        order_cells = ...
            getappdata(fig,'order_cells');

        if ~isempty(order_cells)

            update_current_cell( ...
                fig, ...
                1);

        else

        end
    end

    drawnow;
end


function toggle_show_rejected_cells(fig,src)
    % Simple filtre d'affichage. Ne jamais modifier manual_status,
    % cutoff_status, valid_cells_saved ou les resultats sauvegardes.
    if isempty(fig) || ~ishghandle(fig)
        return;
    end

    setappdata(fig,'show_rejected_cells',logical(get(src,'Value')));
    refresh_selection_order(fig);
end


function select_navigation_sort(fig,src,mode)
    % Choix d'affichage exclusivement : ni retraitement, ni sauvegarde.
    % L'une des deux cases doit toujours rester cochee.
    if isempty(fig) || ~ishghandle(fig)
        return;
    end

    if get(src,'Value') == 0
        set(src,'Value',1);
        return;
    end

    if strcmp(mode,'quality')
        other_tag = 'cb_navigation_similarity';
    else
        other_tag = 'cb_navigation_quality';
    end
    other = findobj(fig,'Tag',other_tag);
    if ~isempty(other) && isgraphics(other)
        set(other,'Value',0);
    end

    setappdata(fig,'navigation_sort_mode',mode);

    % Garder la meme cellule lorsque son nouveau rang existe encore.
    % Utiliser les indices isort1 en cache : pas de raster_processing.
    refresh_selection_order(fig);
    refresh_peak_raster(fig);
end


function update_population_window_title(fig)

    selected_signal = ...
        'combined';

    if isappdata(fig,'selected_signal')

        selected_signal = ...
            char( ...
                string( ...
                    getappdata( ...
                        fig, ...
                        'selected_signal')));
    end

    title_parts = {};

    if isappdata(fig,'viewer_mode') && ...
            getappdata(fig,'viewer_mode')

        title_parts{end+1} = ...
            '[VIEWER MODE]';
    end

    title_parts{end+1} = ...
        upper(selected_signal);

    if isappdata(fig,'type')

        value = ...
            getappdata(fig,'type');

        if ~isempty(value)

            title_parts{end+1} = ...
                char(string(value));
        end
    end

    if isappdata(fig,'line')

        value = ...
            getappdata(fig,'line');

        if ~isempty(value)

            title_parts{end+1} = ...
                char(string(value));
        end
    end

    if isappdata(fig,'animal')

        value = ...
            getappdata(fig,'animal');

        if ~isempty(value)

            title_parts{end+1} = ...
                char(string(value));
        end
    end

    if isappdata(fig,'date')

        value = ...
            getappdata(fig,'date');

        if ~isempty(value)

            title_parts{end+1} = ...
                char(string(value));
        end
    end

    if isappdata(fig,'age')

        value = ...
            getappdata(fig,'age');

        if ~isempty(value)

            title_parts{end+1} = ...
                char(string(value));
        end
    end

    if isappdata(fig,'plane')

        value = ...
            getappdata(fig,'plane');

        if ~isempty(value) && ...
                isnumeric(value) && ...
                isfinite(value(1))

            title_parts{end+1} = ...
                sprintf( ...
                    'Plane %d', ...
                    round(value(1)) - 1);
        end
    end

    set( ...
        fig, ...
        'Name', ...
        strjoin( ...
            title_parts, ...
            ' | '));

end


function value = on_off(tf)

    if tf

        value = 'on';

    else

        value = 'off';
    end
end

function effective_status = ...
        get_effective_cell_status(fig)

    manual_status = [];

    cutoff_status = [];

    if isappdata(fig,'manual_status')

        manual_status = ...
            getappdata( ...
                fig, ...
                'manual_status');
    end

    if isappdata(fig,'cutoff_status')

        cutoff_status = ...
            getappdata( ...
                fig, ...
                'cutoff_status');
    end

    nCells = ...
        max( ...
            numel(manual_status), ...
            numel(cutoff_status));

    if nCells == 0

        effective_status = ...
            zeros(0,1);

        return;
    end

    if numel(manual_status) ~= nCells

        manual_status = ...
            zeros(nCells,1);
    end

    if numel(cutoff_status) ~= nCells

        cutoff_status = ...
            zeros(nCells,1);
    end

    % Cutoff par défaut
    effective_status = ...
        cutoff_status(:);

    % Décision manuelle PRIORITAIRE
    manual_defined = ...
        manual_status ~= 0;

    effective_status(manual_defined) = ...
        manual_status(manual_defined);
end

%% ===================== DETECTION PIPELINE =====================

function opts = convert_opts_ms_to_frames(opts, fs_plane)

    if nargin < 2 || isempty(fs_plane) || ~isfinite(fs_plane) || fs_plane <= 0
        error('convert_opts_ms_to_frames: fs_plane invalide.');
    end

    opts.window_size  = max(1, round(opts.window_size_s * fs_plane));
    opts.refrac_fr    = max(1, round(opts.refrac_ms * fs_plane / 1000));

    % SavGol maintenant normalisé au framerate par plan
    sg = round(opts.savgol_win_ms * fs_plane / 1000);

    % doit être impair et suffisamment grand pour le polynôme
    sg = max(opts.savgol_poly + 2, sg);

    if mod(sg,2) == 0
        sg = sg + 1;
    end

    opts.savgol_win = sg;
end

function DF_sg = savgol_transform(DF, opts)

    sg_win  = opts.savgol_win;
    sg_poly = opts.savgol_poly;

    [NCell, Nz] = size(DF);

    DF_sg = nan(NCell, Nz);

    sgN = max(sg_poly + 2, round(sg_win));
    if mod(sgN,2) == 0
        sgN = sgN + 1;
    end
    if sgN > Nz
        sgN = Nz - (mod(Nz,2) == 0);
    end
    if sgN <= sg_poly
        sgN = sg_poly + 2;
        if mod(sgN,2) == 0
            sgN = sgN + 1;
        end
        if sgN > Nz
            sgN = Nz - (mod(Nz,2) == 0);
        end
    end

    for n = 1:NCell
        sig = DF(n,:);

        if sum(isfinite(sig)) >= sgN
            try
                DF_sg(n,:) = sgolayfilt(sig, sg_poly, sgN);
            catch
                DF_sg(n,:) = sig;
            end
        end
    end
end

function out = detect_peaks_cell_core(x, sigma, opts, bad_frames)

    if nargin < 4
        bad_frames = [];
    end

    out = struct( ...
        'threshold', NaN, ...
        'bad_mask', [], ...
        'locs_raw', []);

    if isempty(x)
        return;
    end

    x = x(:);
    Nx = numel(x);

    if all(~isfinite(x))
        return;
    end

    bad_mask = make_bad_mask(bad_frames, Nx);
    out.bad_mask = bad_mask;

    %seuil_detection = 2.33 * sigma;
    seuil_detection= 3.09 * sigma ;

    if ~isfinite(seuil_detection) || seuil_detection <= 0
        seuil_detection = 0;
    end
    out.threshold = seuil_detection;

    prom = seuil_detection * opts.prominence_factor;

    if ~isfinite(prom) || prom < 0
        prom = 0;
    end

    valid_mask = isfinite(x) & ~bad_mask;

    if ~any(valid_mask)
        return;
    end

    if max(x(valid_mask)) <= seuil_detection
        return;
    end

    % Découpe en segments continus valides
    d = diff([false; valid_mask; false]);
    seg_start = find(d == 1);
    seg_end   = find(d == -1) - 1;

    locs_all = [];

    for s = 1:numel(seg_start)

        idx = seg_start(s):seg_end(s);
        x_seg = x(idx);

        if numel(x_seg) < 3
            continue;
        end

        if max(x_seg) <= seuil_detection
            continue;
        end
        
        mpd = max(1, round(opts.refrac_fr));
        
        warnState = warning('off','signal:findpeaks:largeMinPeakHeight');
    
        try
            max_signal = max(x_seg, [], 'omitnan');
        
            if isempty(max_signal) || ...
               ~isfinite(max_signal) || ...
               max_signal <= seuil_detection
        
                locs_seg = [];
        
            else
                [~, locs_seg] = findpeaks(x_seg, ...
                    'MinPeakHeight', seuil_detection, ...
                    'MinPeakProminence', prom, ...
                    'MinPeakDistance', mpd);
            end
        
        catch
            locs_seg = [];
        end
    
        warning(warnState);

        if ~isempty(locs_seg)
            locs_all = [locs_all; idx(locs_seg(:))']; %#ok<AGROW>
        end
    end

    if isempty(locs_all)
        return;
    end

    locs_all = unique(locs_all(:));
    locs_all = locs_all(locs_all >= 1 & locs_all <= Nx);
    locs_all = locs_all(~bad_mask(locs_all));

    out.locs_raw = locs_all;
end

function [A, SNR, score, cells_sorted_by_quality, quality_min, quality_max, quality_thr0] = ...
    compute_snr_quality(DF, noise_est, opts, bad_frames)

    if nargin < 3 || isempty(opts)
        error('compute_snr_quality requires DF, noise_est, and opts.');
    end

    if nargin < 4
        bad_frames = [];
    end

    if isempty(DF) || ndims(DF) ~= 2
        error('DF must be a 2D matrix [NCell x Nz].');
    end

    [NCell, ~] = size(DF);

    noise_est = noise_est(:);

    if numel(noise_est) ~= NCell
        error('noise_est must have one value per cell (%d expected).', NCell);
    end

    noise_est(~isfinite(noise_est) | noise_est <= 0) = eps;

    A     = zeros(NCell,1);
    SNR   = zeros(NCell,1);
    score = zeros(NCell,1);

    for cid = 1:NCell

        x_detect = DF(cid,:).';
        sigma = noise_est(cid);

        if isempty(x_detect) || all(~isfinite(x_detect))
            continue;
        end

        out = detect_peaks_cell_core(x_detect, sigma, opts, bad_frames);

        if isempty(out.locs_raw)
            continue;
        end

        peak_vals = x_detect(out.locs_raw);
        peak_vals = peak_vals(isfinite(peak_vals));

        if isempty(peak_vals)
            continue;
        end

        A(cid) = median(peak_vals);

        if ~isfinite(A(cid)) || A(cid) < 0
            A(cid) = 0;
        end

        SNR(cid) = A(cid) / sigma;

        if ~isfinite(SNR(cid)) || SNR(cid) < 0
            SNR(cid) = 0;
        end

        n_peaks = numel(out.locs_raw);        

        score(cid) = SNR(cid) .* log1p(n_peaks);

        if ~isfinite(score(cid)) || score(cid) < 0
            score(cid) = 0;
        end
    end

    [~, cells_sorted_by_quality] = sort(score, 'ascend');
    cells_sorted_by_quality = cells_sorted_by_quality(:);

    quality_min  = double(1);
    quality_max  = double(NCell);
    quality_thr0 = double(max(1, round(0.5 * NCell)));
end

function noise_est = estimate_noise(DF)

    [NCell, ~] = size(DF);
    noise_est = nan(NCell, 1);

    for n = 1:NCell
        d = diff(DF(n,:));
        d = d(isfinite(d));

        if ~isempty(d)
            ne = 1.4826 * mad(d, 1) / sqrt(2);
        else
            ne = NaN;
        end

        if ~isfinite(ne) || ne <= 0
            ne = std(DF(n,:), 'omitnan');
        end
        if ~isfinite(ne) || ne <= 0
            ne = eps;
        end

        noise_est(n) = ne;
    end
end

function bad_mask = make_bad_mask(bad_frames, Nx)

    bad_mask = false(Nx,1);

    if isempty(bad_frames)
        return;
    end

    if islogical(bad_frames)
        bf = bad_frames(:);
        L = min(Nx, numel(bf));
        bad_mask(1:L) = bf(1:L);
    else
        bad_idx = round(bad_frames(:));
        bad_idx = bad_idx(isfinite(bad_idx) & bad_idx >= 1 & bad_idx <= Nx);
        bad_mask(bad_idx) = true;
    end
end

%% ===================== PEAK DETECTION AND SAVE =====================
function auto_detect_and_add(fig)

    if ~isappdata(fig,'DF_sg') || ~isappdata(fig,'cell_id')
        return;
    end

    DF  = getappdata(fig,'DF_sg');
    cid = getappdata(fig,'cell_id');

    if isempty(cid) || ~isscalar(cid) || ~isfinite(cid)
        return;
    end

    cid = round(cid);

    if cid < 1 || cid > size(DF,1)
        return;
    end

    viewer_mode = isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode');

    % =====================================================
    % VIEWER MODE NON MODIFIE : pics/seuils sauvegardés
    %
    % Dès qu'un paramètre de détection est modifié, le Viewer
    % utilise la détection active avec les paramètres courants.
    % =====================================================
    viewer_params_modified = ...
        viewer_mode && ...
        isappdata(fig,'detection_params_modified') && ...
        getappdata(fig,'detection_params_modified');

    if viewer_mode && ~viewer_params_modified

        auto_peaks = [];
        seuil = NaN;

        if isappdata(fig,'Acttmp2_saved')
            Acttmp2_saved = getappdata(fig,'Acttmp2_saved');

            if iscell(Acttmp2_saved) && cid <= numel(Acttmp2_saved)
                auto_peaks = Acttmp2_saved{cid};
            end
        end

        if isempty(auto_peaks) && isappdata(fig,'Raster_saved')
            Raster_saved = getappdata(fig,'Raster_saved');

            if ~isempty(Raster_saved) && cid <= size(Raster_saved,1)
                auto_peaks = find(Raster_saved(cid,:));
            end
        end

        if isappdata(fig,'thresholds_saved')
            thresholds_saved = getappdata(fig,'thresholds_saved');

            if ~isempty(thresholds_saved) && cid <= numel(thresholds_saved)
                seuil = thresholds_saved(cid);
            end
        end

        setappdata(fig,'auto_peaks', auto_peaks);
        setappdata(fig,'seuil_detection_last', seuil);

        refresh_data(fig);
        return;
    end

    % =====================================================
    % MODE NORMAL : détection active
    % =====================================================
    if ~isappdata(fig,'opts') || ~isappdata(fig,'noise_est')
        return;
    end

    opts      = getappdata(fig,'opts');
    noise_est = getappdata(fig,'noise_est');

    if isappdata(fig,'bad_frames')
        bad_frames = getappdata(fig,'bad_frames');
    else
        bad_frames = [];
    end

    x = DF(cid,:).';
    sigma = noise_est(cid);

    if ~isfinite(sigma) || sigma <= 0
        sigma = std(x,'omitnan');
    end
    if ~isfinite(sigma) || sigma <= 0
        sigma = eps;
    end

    out = detect_peaks_cell_core(x, sigma, opts, bad_frames);

    setappdata(fig,'auto_peaks', out.locs_raw);
    setappdata(fig,'seuil_detection_last', out.threshold);

    refresh_data(fig);
end

function recompute_n_peaks_all(fig)
    DF     = getappdata(fig,'DF_sg');
    noise_est = getappdata(fig,'noise_est');
    opts      = getappdata(fig,'opts');

    nCells = size(DF,1);
    nFrames = size(DF,2);
    n_peaks_all = zeros(nCells,1);
    raster_all = false(nCells,nFrames);
    peaks_all = cell(nCells,1);
    thresholds_all = nan(nCells,1);

    if isappdata(fig,'bad_frames')
        bad_frames = getappdata(fig,'bad_frames');
    else
        bad_frames = [];
    end

    for cid = 1:nCells
        x = DF(cid,:).';
        sigma = noise_est(cid);

        if ~isfinite(sigma) || sigma <= 0
            sigma = std(x,'omitnan');
        end
        if ~isfinite(sigma) || sigma <= 0
            sigma = eps;
        end

        out = detect_peaks_cell_core(x, sigma, opts, bad_frames);
        peaks_all{cid} = out.locs_raw;
        thresholds_all(cid) = out.threshold;
        n_peaks_all(cid) = numel(out.locs_raw);
        if ~isempty(out.locs_raw)
            raster_all(cid,out.locs_raw) = true;
        end
    end

    % Apercu uniquement : aucun fichier MAT n'est modifie avant confirmer.
    setappdata(fig,'n_peaks_all',n_peaks_all);
    setappdata(fig,'Raster_saved',raster_all);
    setappdata(fig,'Acttmp2_saved',peaks_all);
    setappdata(fig,'thresholds_saved',thresholds_all);
end

function [invalid_cells, valid_cells, DF, F0, noise_est, ...
          Raster, Acttmp2, MAct, thresholds, opts, summary] = ...
    save_peak_matrix(fig, synchronous_frames)

    DF = ...
        getappdata(fig,'DF_sg');

    F0 = ...
        getappdata(fig,'F0');

    opts = ...
        getappdata(fig,'opts');

    noise_est = ...
        getappdata(fig,'noise_est');

    if isappdata(fig,'bad_frames')

        bad_frames = ...
            getappdata(fig,'bad_frames');

    else

        bad_frames = [];
    end

    nCells = ...
        size(DF,1);

    Nz = ...
        size(DF,2);

    %==============================================================
    % Population active dans le référentiel courant
    %==============================================================

    active_indices = ...
        get_active_population_indices( ...
            fig, ...
            nCells);

    %==============================================================
    % État global
    %==============================================================

    manual_status = ...
        getappdata( ...
            fig, ...
            'manual_status');

    cutoff_status = ...
        getappdata( ...
            fig, ...
            'cutoff_status');

    effective_status = ...
        get_effective_cell_status(fig);

    %==============================================================
    % Cellules autorisées
    %
    % -1 = rejetée
    %  0 = non évaluée
    % +1 = conservée
    %==============================================================

    candidate_keep = ...
        effective_status ~= -1;

    %==============================================================
    % Exclusion automatique des cellules sans pic
    %
    % Exception :
    % une cellule gardée manuellement reste autorisée.
    %==============================================================

    n_peaks_all = ...
        getappdata( ...
            fig, ...
            'n_peaks_all');

    has_peaks = ...
        n_peaks_all > 0;

    manual_keep = ...
        manual_status == +1;

    candidate_keep = ...
        candidate_keep & ...
        (has_peaks | manual_keep);

    %==============================================================
    % Matrices globales dans le référentiel courant
    %==============================================================

    Raster_all = ...
        false(nCells,Nz);

    Acttmp2_all = ...
        cell(nCells,1);

    thresholds_all = ...
        nan(nCells,1);

    keep_mask = ...
        false(nCells,1);

    %==============================================================
    % Détection des cellules candidates
    %==============================================================

    candidate_indices = ...
        find(candidate_keep);

    for cid = ...
            candidate_indices(:).'

        x = ...
            DF(cid,:).';

        if isempty(x) || ...
                all(~isfinite(x))

            continue;
        end

        sigma = ...
            noise_est(cid);

        if ~isfinite(sigma) || ...
                sigma <= 0

            sigma = ...
                std( ...
                    x, ...
                    'omitnan');
        end

        if ~isfinite(sigma) || ...
                sigma <= 0

            sigma = eps;
        end

        out = ...
            detect_peaks_cell_core( ...
                x, ...
                sigma, ...
                opts, ...
                bad_frames);

        Acttmp2_all{cid} = ...
            out.locs_raw;

        thresholds_all(cid) = ...
            out.threshold;

        if ~isempty(out.locs_raw)

            Raster_all( ...
                cid, ...
                out.locs_raw) = ...
                true;

            keep_mask(cid) = ...
                true;

        elseif manual_status(cid) == +1

            % Une cellule gardée manuellement peut être
            % conservée même sans pic.
            keep_mask(cid) = ...
                true;
        end
    end

    %==============================================================
    % Indices conservés dans le référentiel courant
    %==============================================================

    valid_cells = ...
        find(keep_mask);

    valid_cells = ...
        valid_cells(:);

    invalid_cells = ...
        ~keep_mask;

    %==============================================================
    % OUTPUT MATRICES
    %==============================================================

    DF = ...
        DF(valid_cells,:);

    F0 = ...
        F0(valid_cells,:);

    noise_est = ...
        noise_est(valid_cells);

    Raster = ...
        Raster_all(valid_cells,:);

    Acttmp2 = ...
        Acttmp2_all(valid_cells);

    thresholds = ...
        thresholds_all(valid_cells);

    %==============================================================
    % MAct
    %==============================================================

    if Nz > synchronous_frames

        MAct = ...
            zeros( ...
                1, ...
                Nz - synchronous_frames);

        for i = 1:(Nz - synchronous_frames)

            MAct(i) = ...
                sum( ...
                    max( ...
                        Raster(:, ...
                            i:i+synchronous_frames), ...
                        [], ...
                        2));
        end

    else

        MAct = ...
            zeros(1,0);
    end

    %==============================================================
    % SELECTION SUMMARY
    %
    % Tous les indices sont exprimés dans le référentiel courant.
    %
    % selected_signal permet de savoir lequel :
    %
    %   'gcamp'
    %   'combined'
    %   'electroporated'
    %
    % Aucun champ du summary n'impose donc "combined".
    %==============================================================

    selected_signal = ...
        char( ...
            string( ...
                getappdata( ...
                    fig, ...
                    'selected_signal')));

    summary = struct();

    summary.selected_signal = ...
        selected_signal;

    summary.active_indices = ...
        active_indices(:);

    summary.valid_cells = ...
        valid_cells(:);

    summary.manual_status = ...
        manual_status(:);

    summary.cutoff_status = ...
        cutoff_status(:);

    summary.effective_status = ...
        effective_status(:);

    %==============================================================
    % Informations sur les populations
    %==============================================================

    electroporated_indices = ...
        getappdata( ...
            fig, ...
            'electroporated_indices');

    electroporated_indices = ...
        normalize_electroporated_indices( ...
            electroporated_indices, ...
            nCells);

    summary.electroporated_indices = ...
        electroporated_indices(:);

    if isempty(electroporated_indices)

        summary.gcamp_indices = ...
            (1:nCells).';

    else

        summary.gcamp_indices = ...
            setdiff( ...
                (1:nCells).', ...
                electroporated_indices, ...
                'stable');
    end

    %==============================================================
    % Statistiques
    %==============================================================

    valid_active_cells = ...
        intersect( ...
            valid_cells, ...
            active_indices, ...
            'stable');

    summary.n_total = ...
        numel(active_indices);

    summary.n_kept_final = ...
        numel(valid_active_cells);

    summary.n_manual_keep = ...
        sum( ...
            manual_status(active_indices) == +1);

    summary.n_manual_excl = ...
        sum( ...
            manual_status(active_indices) == -1);

    summary.n_cutoff_keep = ...
        sum( ...
            cutoff_status(active_indices) == +1);

    summary.n_cutoff_excl = ...
        sum( ...
            cutoff_status(active_indices) == -1);

    %==============================================================
    % Commentaire
    %==============================================================

    if isappdata(fig,'comment')
        summary.comment = getappdata(fig,'comment');
    else
        summary.comment = '';
    end
end

%% ===================== NAVIGATION AND CUTOFF =====================

function update_current_cell(fig, idx_slider)

    if ~isappdata(fig,'order_cells')
        return;
    end

    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells)
        return;
    end

    %==============================================================
    % CHANGEMENT DE CELLULE : ARRETER LE FILM PRECEDENT
    %==============================================================

    reset_roi_movie_display(fig);
    setappdata(fig,'roi_movie_visible',false);

    idx = round(idx_slider);
    idx = max(1, min(numel(order_cells), idx));

    cid = order_cells(idx);

    setappdata(fig,'current_rank', idx);
    setappdata(fig,'nav_rank', idx);
    setappdata(fig,'cell_id', cid);

    sldr = findobj(fig,'Tag','sldr_nav_cell');
    if ~isempty(sldr) && isgraphics(sldr)
        set(sldr,'Min',1,'Max',numel(order_cells),'Value',idx);
        step = 1/max(1,numel(order_cells)-1);
        set(sldr,'SliderStep',[step min(1,10*step)]);
    end

    lbl = findobj(fig,'Tag','lbl_nav_cell');
    if ~isempty(lbl)
        lbl.String = sprintf('Navigation cellule\n(%d / %d)', idx, numel(order_cells));
    end

    update_navigation_identification(fig);

    setappdata(fig,'autotervals', []);
    if isappdata(fig,'seuil_detection_last')
        rmappdata(fig,'seuil_detection_last');
    end

    auto_detect_and_add(fig);
end

function next_cell(fig)

    if ~isappdata(fig,'current_rank')
        idx = 1;
    else
        idx = getappdata(fig,'current_rank');
    end

    if ~isappdata(fig,'order_cells')
        return;
    end
    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells)
        return;
    end

    idx = min(idx + 1, numel(order_cells));
    update_current_cell(fig, idx);
end

function prev_cell(fig)

    if ~isappdata(fig,'current_rank')
        idx = 1;
    else
        idx = getappdata(fig,'current_rank');
    end

    if ~isappdata(fig,'order_cells')
        return;
    end
    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells)
        return;
    end

    idx = max(idx - 1, 1);
    update_current_cell(fig, idx);
end

function goto_navigationdex(fig, hEdit)

    if ~isappdata(fig,'order_cells')
        return;
    end

    order_cells = getappdata(fig,'order_cells');
    if isempty(order_cells)
        return;
    end

    if numel(hEdit) > 1
        hEdit = hEdit(1);
    end
    if isempty(hEdit) || ~isgraphics(hEdit)
        return;
    end

    txt = get(hEdit, 'String');
    idx = str2double(txt);

    if ~isfinite(idx)
        idx = 1;
    end

    idx = round(idx);
    idx = max(1, min(numel(order_cells), idx));

    setappdata(fig,'nav_rank', idx);

    viewer_mode = isappdata(fig,'viewer_mode') && getappdata(fig,'viewer_mode');
    locked = isappdata(fig,'cutoff_locked') && getappdata(fig,'cutoff_locked');

    if ~viewer_mode && ~locked
        setappdata(fig,'cutoff_rank', idx);
    end

    set(hEdit, 'String', num2str(idx));
    update_current_cell(fig, idx);
end

%% ===================== CUTOFF =====================

function apply_auto_cutoff(fig)

    if ~ishghandle(fig)
        return;
    end

    if ~isappdata(fig,'n_peaks_all') || ...
            ~isappdata(fig,'opts')

        return;
    end

    n_peaks_all = ...
        getappdata( ...
            fig, ...
            'n_peaks_all');

    opts = ...
        getappdata( ...
            fig, ...
            'opts');

    if isempty(n_peaks_all)
        return;
    end

    nCells = ...
        numel(n_peaks_all);

    active_indices = ...
        get_active_population_indices( ...
            fig, ...
            nCells);

    if isempty(active_indices)
        return;
    end

    %==========================================================
    % Peaks
    %==========================================================

    good_by_peaks = ...
        n_peaks_all >= ...
        opts.min_n_peaks_cutoff;

    %==========================================================
    % Mask size
    %==========================================================

    mask_sizes = [];

    if isappdata(fig,'mask_sizes')

        mask_sizes = ...
            getappdata( ...
                fig, ...
                'mask_sizes');
    end

    if ~isempty(mask_sizes) && ...
            numel(mask_sizes) == nCells

        good_by_mask = ...
            mask_sizes >= ...
            opts.min_mask_um2;

    else

        good_by_mask = ...
            true(nCells,1);
    end

    %==========================================================
    % Connectivity
    %==========================================================

    mask_connectivity_ratio = [];

    if isappdata(fig,'mask_connectivity_ratio')

        mask_connectivity_ratio = ...
            getappdata( ...
                fig, ...
                'mask_connectivity_ratio');
    end

    if ~isempty(mask_connectivity_ratio) && ...
            numel(mask_connectivity_ratio) == nCells

        good_by_connectivity = ...
            mask_connectivity_ratio >= ...
            opts.min_mask_connectivity;

    else

        good_by_connectivity = ...
            true(nCells,1);
    end

    cutoff_good = ...
        good_by_peaks & ...
        good_by_mask & ...
        good_by_connectivity;

    %==========================================================
    % cutoff_status GLOBAL
    %
    % On modifie UNIQUEMENT la population actuellement affichée.
    %
    % Mais puisque les indices sont Combined, le résultat est
    % immédiatement visible dans les autres vues.
    %==========================================================

    cutoff_status = ...
        getappdata( ...
            fig, ...
            'cutoff_status');

    if isempty(cutoff_status) || ...
            numel(cutoff_status) ~= nCells

        cutoff_status = ...
            zeros(nCells,1);
    end

    cutoff_status(active_indices) = -1;

    cutoff_status( ...
        active_indices( ...
            cutoff_good(active_indices))) = +1;

    setappdata( ...
        fig, ...
        'cutoff_status', ...
        cutoff_status);

    setappdata( ...
        fig, ...
        'cutoff_validated', ...
        true);

    setappdata( ...
        fig, ...
        'cutoff_locked', ...
        true);

    selected_cells_from_cutoff = ...
        active_indices( ...
            cutoff_status(active_indices) == +1);

    setappdata( ...
        fig, ...
        'selected_cells_from_cutoff', ...
        selected_cells_from_cutoff(:));

    selected_signal = ...
        char( ...
            string( ...
                getappdata( ...
                    fig, ...
                    'selected_signal')));

    fprintf('\n');
    fprintf( ...
        'Cutoff appliqué à %s\n', ...
        upper(selected_signal));

    fprintf( ...
        '  Total        : %d\n', ...
        numel(active_indices));

    fprintf( ...
        '  Conservées   : %d\n', ...
        sum( ...
            cutoff_status(active_indices) == +1));

    fprintf( ...
        '  Exclues      : %d\n', ...
        sum( ...
            cutoff_status(active_indices) == -1));

    fprintf( ...
        '  Peaks        : >= %d\n', ...
        opts.min_n_peaks_cutoff);

    fprintf( ...
        '  Mask         : >= %.1f um²\n', ...
        opts.min_mask_um2);

    fprintf( ...
        '  Connectivity : >= %.2f\n', ...
        opts.min_mask_connectivity);

    refresh_selection_order(fig);
end


function validate_selection_filter(fig)

    if ~ishghandle(fig)
        return;
    end

    apply_auto_cutoff(fig);

    % Le tri initial a ete calcule sur les cellules acceptees par cutoff.
    % Si l'utilisateur revalide un cutoff modifie, actualiser son cache.
    % Une suppression ISOLEE ne relance jamais raster_processing : elle
    % disparait simplement de l'ordre memorise. Le tri final, lui, sera
    % systematiquement recalcule au clic sur Confirmer selection.
    if ~getappdata(fig,'viewer_mode')
        DF = getappdata(fig,'DF_sg');
        accepted = find(get_navigation_kept_mask(fig,size(DF,1),false));
        previous = getappdata(fig,'peak_sort_source_ids');
        if isempty(previous)
            previous = zeros(0,1);
        end
        removed = setdiff(previous,accepted);
        added = setdiff(accepted,previous);
        df_changed = isappdata(fig,'peak_sort_df_changed') && ...
            getappdata(fig,'peak_sort_df_changed');
        if ~getappdata(fig,'peak_sort_initialized') || df_changed || ...
                ~isempty(added) || numel(removed)>1
            initialize_peak_raster_sort(fig,accepted,[],[],[],false);
        end
    end
    refresh_peak_raster(fig);

    if isappdata(fig,'order_cells')

        order_cells = ...
            getappdata( ...
                fig, ...
                'order_cells');

        fprintf( ...
            'Population affichée après cutoff : %d cellules\n', ...
            numel(order_cells));
    end
end

function kept = get_navigation_kept_mask(fig,nCells,viewer_mode)
    % Referentiel ORIGINAL de F : jamais les rangs tries de navigation.
    if viewer_mode
        % La selection deja sauvegardee est la source de verite ; le cutoff
        % historique seul ne permet pas de reconstruire tous les rejets.
        kept = false(nCells,1);
        saved = getappdata(fig,'valid_cells_saved');
        if ~isempty(saved)
            saved = round(double(saved(:)));
            saved = saved(isfinite(saved) & saved>=1 & saved<=nCells);
            kept(saved) = true;
        end
    else
        % Pendant la detection, le cutoff automatique a deja ete applique.
        % 0 = non evaluee : ce n'est pas une cellule acceptee.
        effective = get_effective_cell_status(fig);
        kept = false(nCells,1);
        n = min(nCells,numel(effective));
        kept(1:n) = effective(1:n)==1;
    end

    % Les interventions manuelles restent prioritaires dans les deux modes.
    manual = getappdata(fig,'manual_status');
    if ~isempty(manual)
        manual = manual(:);
        n = min(nCells,numel(manual));
        kept(1:n) = (kept(1:n) | manual(1:n)==1) & manual(1:n)~=-1;
    end
end


function ids = sort_cell_ids_for_display(fig,ids)
    % Les IDs sont TOUJOURS les indices originaux de F/DF/Raster.
    % Les permutations isort1, au contraire, indexent les lignes du DF
    % selectionne. Ne jamais les appliquer directement au raster complet.
    ids = ids(:);
    if isempty(ids)
        return;
    end

    mode = getappdata(fig,'navigation_sort_mode');
    if strcmp(mode,'quality')
        quality = getappdata(fig,'score_quality');
        scores = -inf(numel(ids),1);
        valid = ids>=1 & ids<=numel(quality);
        scores(valid) = double(quality(ids(valid)));
        scores(~isfinite(scores)) = -inf;

        % Meilleure qualite EN HAUT. En cas d'egalite, ID croissant.
        [~,permutation] = sortrows([-scores double(ids)],[1 2]);
        ids = ids(permutation);
    else
        % Viewer : isort1 sauvegarde. Detection : isort1 du cutoff.
        % Les cellules recemment rejetees sont filtrees sans nouveau tri.
        ids = sorted_original_peak_ids(fig,ids);
    end
end


function refresh_selection_order(fig)

    if ~isappdata(fig,'DF_sg') || isempty(getappdata(fig,'DF_sg'))
        update_empty_navigation(fig);
        return;
    end

    nCells = size(getappdata(fig,'DF_sg'),1);

    %==========================================================
    % Mode viewer
    %==========================================================

    viewer_mode = ...
        isappdata(fig,'viewer_mode') && ...
        getappdata(fig,'viewer_mode');

    %==========================================================
    % Population active
    %==========================================================

    active_indices = ...
        get_active_population_indices( ...
            fig, ...
            nCells);

    kept = get_navigation_kept_mask(fig,nCells,viewer_mode);

    if strcmp(getappdata(fig,'navigation_sort_mode'),'quality')
        % Inclure egalement les rejetees dans le classement par qualite :
        % cocher Show rejected cells ne change donc pas les rangs relatifs.
        order_cells_all = sort_cell_ids_for_display(fig,active_indices);
    else
        % isort1 ne porte que sur les cellules acceptees : conserver son
        % ordre, puis placer les rejetees en fin de navigation optionnelle.
        accepted_ids = active_indices(kept(active_indices));
        rejected_ids = active_indices(~kept(active_indices));
        order_cells_all = [ ...
            sort_cell_ids_for_display(fig,accepted_ids); ...
            sort_cell_ids_for_display(fig,rejected_ids)];
    end

    % Conserver le pool COMPLET de la population (y compris 0 pic).
    % Le checkbox change uniquement la liste de navigation.
    setappdata(fig,'order_cells_all',order_cells_all);

    show_rejected = ...
        isappdata(fig,'show_rejected_cells') && ...
        getappdata(fig,'show_rejected_cells');

    if show_rejected
        order_cells = order_cells_all;
    else
        order_cells = order_cells_all(kept(order_cells_all));
    end

    setappdata( ...
        fig, ...
        'order_cells', ...
        order_cells);

    if isempty(order_cells)

        update_empty_navigation(fig);
        return;
    end

    %==========================================================
    % Conserver cellule courante si possible
    %==========================================================

    old_cid = [];

    if isappdata(fig,'cell_id')

        old_cid = ...
            getappdata( ...
                fig, ...
                'cell_id');
    end

    idx = 1;

    if ~isempty(old_cid)

        k = ...
            find( ...
                order_cells == old_cid, ...
                1);

        if ~isempty(k)
            idx = k;
        end
    end

    idx = ...
        max( ...
            1, ...
            min( ...
                numel(order_cells), ...
                idx));

    setappdata( ...
        fig, ...
        'current_rank', ...
        idx);

    setappdata( ...
        fig, ...
        'nav_rank', ...
        idx);

    setappdata( ...
        fig, ...
        'cell_id', ...
        order_cells(idx));

    %==========================================================
    % Slider
    %==========================================================

    sldr = ...
        findobj( ...
            fig, ...
            'Tag', ...
            'sldr_nav_cell');

    if ~isempty(sldr) && ...
            isgraphics(sldr)

        n = ...
            numel(order_cells);

        step = ...
            1 / ...
            max(1,n-1);

        set( ...
            sldr, ...
            'Min',1, ...
            'Max',max(1,n), ...
            'Value',idx, ...
            'SliderStep', ...
            [step min(1,10*step)], ...
            'Enable','on');
    end

    % Reactiver les decisions manuelles apres un pool provisoirement vide.
    set(findobj(fig,'Style','pushbutton','String','Garder cellule'),'Enable','on');
    set(findobj(fig,'Style','pushbutton','String','Exclure cellule'),'Enable','on');

    %==========================================================
    % Label navigation
    %==========================================================

    lbl = ...
        findobj( ...
            fig, ...
            'Tag', ...
            'lbl_nav_cell');

    if ~isempty(lbl)

        lbl.String = ...
            sprintf( ...
                'Navigation cellule\n(%d / %d)', ...
                idx, ...
                numel(order_cells));
    end

    update_navigation_identification(fig);

    %==========================================================
    % Affichage cellule
    %==========================================================

    auto_detect_and_add(fig);
end


function update_empty_navigation(fig)

    setappdata(fig,'order_cells',[]);
    setappdata(fig,'cell_id',[]);
    setappdata(fig,'current_rank',[]);
    setappdata(fig,'nav_rank',[]);
    % Pas de cellule courante : retirer le marqueur a droite du raster.
    update_current_cell_raster_arrow(fig);

    sldr = ...
        findobj( ...
            fig, ...
            'Tag', ...
            'sldr_nav_cell');

    if ~isempty(sldr) && ...
            isgraphics(sldr)

        set( ...
            sldr, ...
            'Min',1, ...
            'Max',1, ...
            'Value',1, ...
            'SliderStep',[1 1], ...
            'Enable','off');
    end

    set(findobj(fig,'Style','pushbutton','String','Garder cellule'),'Enable','off');
    set(findobj(fig,'Style','pushbutton','String','Exclure cellule'),'Enable','off');

    lbl = ...
        findobj( ...
            fig, ...
            'Tag', ...
            'lbl_nav_cell');

    if ~isempty(lbl)

        lbl.String = ...
            sprintf('Navigation cellule\n(0 / 0)');
    end

    hIdentity = findobj(fig,'Tag','lbl_nav_identification');
    if ~isempty(hIdentity) && isgraphics(hIdentity)
        set(hIdentity,'String','');
    end

    % Ne pas laisser la trace d'une cellule rejetee dans une navigation
    % devenue vide. Les badframes et le marqueur temporel sont conserves.
    if isappdata(fig,'ax1')
        ax = getappdata(fig,'ax1');
        if ~isempty(ax) && isgraphics(ax,'axes')
            kids = allchild(ax);
            keep_kids = false(size(kids));
            hBad = getappdata(fig,'hBadPatch_ax1');
            hCursor = getappdata(fig,'shared_movie_cursor');
            if ~isempty(hBad) && isgraphics(hBad)
                keep_kids = keep_kids | kids == hBad;
            end
            if ~isempty(hCursor) && isgraphics(hCursor)
                keep_kids = keep_kids | kids == hCursor;
            end
            delete(kids(~keep_kids));
            text(ax,0.5,0.5,'Aucune cellule acceptee', ...
                'Units','normalized','HorizontalAlignment','center', ...
                'HitTest','off');
        end
    end
    if isappdata(fig,'axF0')
        ax = getappdata(fig,'axF0');
        if ~isempty(ax) && isgraphics(ax,'axes')
            kids = allchild(ax);
            keep_kids = false(size(kids));
            hBad = getappdata(fig,'hBadPatch_axF0');
            hCursor = getappdata(fig,'shared_movie_cursor_f0');
            if ~isempty(hBad) && isgraphics(hBad)
                keep_kids = keep_kids | kids == hBad;
            end
            if ~isempty(hCursor) && isgraphics(hCursor)
                keep_kids = keep_kids | kids == hCursor;
            end
            delete(kids(~keep_kids));
        end
    end
    if isappdata(fig,'axROI')
        ax = getappdata(fig,'axROI');
        if ~isempty(ax) && isgraphics(ax,'axes')
            % Quand aucune cellule ne peut etre affichee, ne pas montrer
            % son ancien masque ni son ancien film ROI.
            reset_roi_movie_display(fig);
            cla(ax);
            text(ax,0.5,0.5,'Aucune cellule', ...
                'Units','normalized','HorizontalAlignment','center');
            axis(ax,'off');
        end
    end
end

function update_navigation_identification(fig)

    % Indice LOCAL de la cellule dans la population active, a ne pas
    % confondre avec son rang dans la navigation triee par qualite.
    hIdentity = findobj(fig,'Tag','lbl_nav_identification');

    if isempty(hIdentity) || ~isgraphics(hIdentity) || ...
            ~isappdata(fig,'cell_id') || ~isappdata(fig,'DF_sg')
        return;
    end

    cell_id = getappdata(fig,'cell_id');
    DF = getappdata(fig,'DF_sg');

    if isempty(cell_id) || ~isscalar(cell_id) || ...
            ~isfinite(cell_id) || isempty(DF)
        set(hIdentity,'String','');
        return;
    end

    population_indices = ...
        get_active_population_indices(fig,size(DF,1));

    population_index = ...
        find(population_indices == cell_id,1);

    if isempty(population_index)
        set(hIdentity,'String','');
        return;
    end

    selected_signal = char(string(getappdata(fig,'selected_signal')));
    switch lower(selected_signal)
        case 'gcamp'
            signal_name = 'GCaMP';
        case 'electroporated'
            signal_name = 'Electroporated';
        case 'combined'
            signal_name = 'Combined';
        otherwise
            signal_name = selected_signal;
    end

    index_label = sprintf('%s : %d/%d', ...
        signal_name, population_index, numel(population_indices));

    if isappdata(fig,'iscell_idx_display')
        iscell_indices = getappdata(fig,'iscell_idx_display');

        if cell_id >= 1 && cell_id <= numel(iscell_indices) && ...
                isfinite(iscell_indices(cell_id))
            index_label = sprintf('%s\niscell : %d', ...
                index_label,round(iscell_indices(cell_id))-1);
        end
    end

    set(hIdentity,'String',index_label);
end

function navigate_cells(fig, evnt)

    switch evnt.Key
        case 'rightarrow'
            next_cell(fig);

        case 'leftarrow'
            prev_cell(fig);

        case {'delete','backspace'}
            exclude_cell(fig);

        case {'return','space'}
            keep_cell(fig);
    end
end


%% ===================== MANUAL SELECTION =====================

function keep_cell(fig)

    if ~ishghandle(fig) || ...
            ~isappdata(fig,'cell_id') || ...
            ~isappdata(fig,'manual_status')

        return;
    end

    cid = ...
        round( ...
            getappdata( ...
                fig, ...
                'cell_id'));

    manual_status = ...
        getappdata( ...
            fig, ...
            'manual_status');

    if isempty(cid) || ...
            cid < 1 || ...
            cid > numel(manual_status)

        return;
    end

    %==========================================================
    % Décision manuelle
    %
    % Fonctionne en mode normal ET en Viewer.
    % La décision manuelle est prioritaire sur le cutoff.
    %==========================================================

    manual_status(cid) = ...
        +1;

    setappdata( ...
        fig, ...
        'manual_status', ...
        manual_status);
    
    setappdata(fig,'selection_modified',true);
    update_population_action_buttons(fig);

    %==========================================================
    % Rafraîchir immédiatement l'affichage
    %
    % Si les rejetees sont masquees, une cellule exclue quitte
    % immediatement la navigation ; elle reste inspectable en cochant
    % Show rejected cells.
    %==========================================================

    refresh_selection_order(fig);
    refresh_peak_raster(fig);

    drawnow;
end

function exclude_cell(fig)

    if ~ishghandle(fig) || ...
            ~isappdata(fig,'cell_id') || ...
            ~isappdata(fig,'manual_status')

        return;
    end

    cid = ...
        round( ...
            getappdata( ...
                fig, ...
                'cell_id'));

    manual_status = ...
        getappdata( ...
            fig, ...
            'manual_status');

    if isempty(cid) || ...
            cid < 1 || ...
            cid > numel(manual_status)

        return;
    end

    %==========================================================
    % Décision manuelle
    %
    % Fonctionne en mode normal ET en Viewer.
    %==========================================================

    manual_status(cid) = ...
        -1;

    setappdata( ...
        fig, ...
        'manual_status', ...
        manual_status);

    setappdata(fig,'selection_modified',true);
    update_population_action_buttons(fig);

    %==========================================================
    % Rafraîchir immédiatement l'affichage
    %==========================================================

    refresh_selection_order(fig);
    refresh_peak_raster(fig);

    drawnow;
end

function update_population_action_buttons(fig)

    if ~ishghandle(fig)
        return;
    end

    viewer_mode = ...
        isappdata(fig,'viewer_mode') && ...
        getappdata(fig,'viewer_mode');

    btn_confirm = ...
        findobj( ...
            fig, ...
            'Tag', ...
            'btn_confirm_selection');

    %==========================================================
    % VIEWER
    %
    % Confirmation depuis n'importe quelle population,
    % mais uniquement s'il existe une modification.
    %==========================================================

    if viewer_mode

        modified = ...
            (isappdata(fig,'selection_modified') && ...
             getappdata(fig,'selection_modified')) || ...
            (isappdata(fig,'recording_keep_modified') && ...
             getappdata(fig,'recording_keep_modified')) || ...
            isempty(normalize_recording_keep(getappdata(fig,'recording_keep')));

        if ~isempty(btn_confirm)

            set( ...
                btn_confirm, ...
                'Enable', ...
                on_off(modified));
        end

        return;
    end

    %==========================================================
    % MODE NORMAL
    %
    % Confirmation depuis n'importe quelle population.
    %==========================================================

    if ~isempty(btn_confirm)

        set( ...
            btn_confirm, ...
            'Enable', ...
            'on');
    end
end

function value = normalize_recording_keep(value)
    if ~(isnumeric(value) || islogical(value)) || ...
            ~isscalar(value) || ~isreal(value) || ...
            ~isfinite(double(value)) || ~ismember(double(value),[0 1])
        value = [];
    else
        value = double(value);
    end
end

function refresh_recording_keep_indicator(fig)
    if ~ishghandle(fig), return; end
    value = normalize_recording_keep(getappdata(fig,'recording_keep'));
    led = findobj(fig,'Tag','lbl_recording_led');
    keep = findobj(fig,'Tag','btn_keep_recording');
    reject = findobj(fig,'Tag','btn_reject_recording');
    if isempty(value)
        c = [.50 .50 .50];
    elseif value == 1
        c = [.06 .65 .12];
    else
        c = [.87 .12 .12];
    end
    if ~isempty(led), set(led,'ForegroundColor',c); end
    if ~isempty(keep)
        set(keep,'BackgroundColor',[.94 .94 .94],'FontWeight','normal');
        if isequal(value,1)
            set(keep,'BackgroundColor',[.28 .77 .34],'FontWeight','bold');
        end
    end
    if ~isempty(reject)
        set(reject,'BackgroundColor',[.94 .94 .94],'FontWeight','normal');
        if isequal(value,0)
            set(reject,'BackgroundColor',[.94 .39 .39],'FontWeight','bold');
        end
    end
end

function set_recording_keep(fig,value)
    if ~ishghandle(fig), return; end
    % Changing the indicator while confirmation is pending returns to edit.
    if getappdata(fig,'confirmation_pending')
        undo_recording_confirmation(fig);
    end
    value = normalize_recording_keep(value);
    if isempty(value), return; end
    setappdata(fig,'recording_keep',value);
    original = getappdata(fig,'recording_keep_initial');
    setappdata(fig,'recording_keep_modified',~isequal(original,value));
    refresh_recording_keep_indicator(fig);
    update_population_action_buttons(fig);
end

function answered = ask_recording_keep(fig,action)
    % Cancel (or closing the dialog) is explicitly a VALID undecided state.
    % It must never block closing the Viewer or confirming cell selection.
    answered = false;
    if ~ishghandle(fig), return; end
    if nargin < 2, action = 'confirm'; end

    if strcmp(action,'close')
        consequence = 'Cancel : fermer sans renseigner le statut.';
    else
        consequence = 'Cancel : confirmer la selection sans renseigner le statut.';
    end

    current_plane = getappdata(fig,'plane') - 1;
    response = questdlg( ...
        sprintf(['Souhaites-tu conserver le plan %d de cet enregistrement ' ...
                 'pour les analyses ulterieures ?\n\n%s'], ...
                 current_plane,consequence), ...
        sprintf('Decision pour le plan %d',current_plane), ...
        'Keep recording','Rejected recording','Cancel','Cancel');

    switch response
        case 'Keep recording'
            set_recording_keep(fig,1);
            answered = true;
        case 'Rejected recording'
            set_recording_keep(fig,0);
            answered = true;
        otherwise
            % Keep recording_keep = [] and continue the caller's action.
    end
end

function undo_recording_confirmation(fig)
    if ~ishghandle(fig) || ~getappdata(fig,'confirmation_pending')
        return;
    end
    % Un choix impose uniquement par la question est annule avec ce retour.
    if getappdata(fig,'recording_keep_prompted_for_confirmation')
        original = getappdata(fig,'recording_keep_initial');
        setappdata(fig,'recording_keep',original);
        setappdata(fig,'recording_keep_modified',false);
    end
    setappdata(fig,'recording_keep_prompted_for_confirmation',false);
    setappdata(fig,'confirmation_pending',false);
    main = findobj(fig,'Tag','btn_confirm_selection');
    back = findobj(fig,'Tag','btn_undo_confirmation');
    if ~isempty(main)
        set(main,'String','Confirmer sélection', ...
            'Position',[0.05 0.025 0.90 0.065]);
    end
    if ~isempty(back), set(back,'Visible','off'); end
    refresh_recording_keep_indicator(fig);
    update_population_action_buttons(fig);
end

function confirm_selection_and_close(fig,synchronous_frames)
    if isempty(fig) || ~ishghandle(fig), return; end
    if ~getappdata(fig,'confirmation_pending')
        % Demander le statut avant l'etape de confirmation. Cancel laisse
        % le voyant gris et ne bloque pas la sauvegarde de la selection.
        if isempty(normalize_recording_keep(getappdata(fig,'recording_keep')))
            answered = ask_recording_keep(fig,'confirm');
            setappdata(fig,'recording_keep_prompted_for_confirmation',answered);
        else
            setappdata(fig,'recording_keep_prompted_for_confirmation',false);
        end
        % Etape reversible. Aucune sortie / aucun MAT encore modifie.
        setappdata(fig,'confirmation_pending',true);
        main = findobj(fig,'Tag','btn_confirm_selection');
        back = findobj(fig,'Tag','btn_undo_confirmation');
        if ~isempty(main)
            set(main,'String','Enregistrer et fermer', ...
                'Position',[0.05 0.025 0.48 0.065],'Enable','on');
        end
        if ~isempty(back), set(back,'Visible','on'); end
        return;
    end
    % Second clic : validation definitive de la selection + recording.
    setappdata(fig,'selection_confirmed',true);
    finalize_and_close(fig,synchronous_frames);
end

function [ ...
        invalid_cells, ...
        valid_cells, ...
        DF_sg, ...
        DF_raw, ...
        F0, ...
        noise_est, ...
        Raster, ...
        Acttmp2, ...
        MAct, ...
        thresholds, ...
        summary ...
    ] = ...
    save_viewer_selection( ...
        fig, ...
        synchronous_frames)

    %==============================================================
    % PARAMETRES MODIFIES DANS LE VIEWER
    %
    % Pendant le déplacement des sliders, seule la cellule courante
    % est recalculée pour garder une interface fluide.
    % Au moment de Confirmer, on recalcule tout le plan avec les
    % paramètres courants avant la sauvegarde.
    %==============================================================

    params_modified = ...
        isappdata(fig,'detection_params_modified') && ...
        getappdata(fig,'detection_params_modified');

    if params_modified
        recompute_viewer_detection_all(fig);
    end

    %==============================================================
    % Données complètes reconstruites par le Viewer
    %==============================================================

    DF_sg_all = ...
        getappdata(fig,'DF_sg');

    DF_raw_all = ...
        getappdata(fig,'DF_raw');

    F0_all = ...
        getappdata(fig,'F0');

    noise_est_all = ...
        getappdata(fig,'noise_est');

    Raster_all = ...
        getappdata(fig,'Raster_saved');

    Acttmp2_all = ...
        getappdata(fig,'Acttmp2_saved');

    thresholds_all = ...
        getappdata(fig,'thresholds_saved');

    nCells = ...
        size(DF_sg_all,1);

    Nz = ...
        size(DF_sg_all,2);

    %==============================================================
    % Sélection qui existait avant l'ouverture du Viewer
    %==============================================================

    valid_cells_saved = [];

    if isappdata(fig,'valid_cells_saved')

        valid_cells_saved = ...
            getappdata(fig,'valid_cells_saved');
    end

    valid_cells_saved = ...
        round(double(valid_cells_saved(:)));

    valid_cells_saved = ...
        valid_cells_saved( ...
            isfinite(valid_cells_saved) & ...
            valid_cells_saved >= 1 & ...
            valid_cells_saved <= nCells);

    valid_cells_saved = ...
        unique(valid_cells_saved,'stable');

    %==============================================================
    % Base = sélection précédemment sauvegardée
    %==============================================================

    keep_mask = ...
        false(nCells,1);

    keep_mask(valid_cells_saved) = ...
        true;

    %==============================================================
    % Corrections manuelles Viewer
    %
    % +1 = ajout / conservation forcée
    % -1 = retrait forcé
    %  0 = garder l'état précédemment sauvegardé
    %==============================================================

    manual_status = ...
        getappdata(fig,'manual_status');

    if isempty(manual_status) || ...
            numel(manual_status) ~= nCells

        manual_status = ...
            zeros(nCells,1);

    else

        manual_status = ...
            manual_status(:);
    end

    keep_mask(manual_status == +1) = ...
        true;

    keep_mask(manual_status == -1) = ...
        false;

    %==============================================================
    % Résultat final
    %==============================================================

    valid_cells = ...
        find(keep_mask);

    valid_cells = ...
        valid_cells(:);

    invalid_cells = ...
        ~keep_mask;

    %==============================================================
    % Réduction des matrices déjà calculées
    %==============================================================

    DF_sg = ...
        DF_sg_all(valid_cells,:);

    DF_raw = ...
        DF_raw_all(valid_cells,:);

    F0 = ...
        F0_all(valid_cells,:);

    noise_est = ...
        noise_est_all(valid_cells);

    Raster = ...
        Raster_all(valid_cells,:);

    Acttmp2 = ...
        Acttmp2_all(valid_cells);

    thresholds = ...
        thresholds_all(valid_cells);

    %==============================================================
    % MAct doit refléter la nouvelle population retenue
    %==============================================================

    if Nz > synchronous_frames

        MAct = ...
            zeros( ...
                1, ...
                Nz - synchronous_frames);

        for i = 1:(Nz - synchronous_frames)

            MAct(i) = ...
                sum( ...
                    max( ...
                        Raster(:,i:i+synchronous_frames), ...
                        [], ...
                        2));
        end

    else

        MAct = ...
            zeros(1,0);
    end

    %==============================================================
    % Summary
    %==============================================================

    summary = ...
        struct();

    if isappdata(fig,'selection_summary_saved')

        tmp = ...
            getappdata(fig,'selection_summary_saved');

        if isstruct(tmp)
            summary = tmp;
        end
    end

    cutoff_status = [];

    if isappdata(fig,'cutoff_status')
        cutoff_status = getappdata(fig,'cutoff_status');
    end

    if isempty(cutoff_status) || ...
            numel(cutoff_status) ~= nCells

        cutoff_status = ...
            zeros(nCells,1);

    else

        cutoff_status = ...
            cutoff_status(:);
    end

    effective_status = ...
        zeros(nCells,1);

    effective_status(keep_mask) = ...
        +1;

    effective_status(~keep_mask) = ...
        -1;

    summary.valid_cells = ...
        valid_cells(:);

    summary.manual_status = ...
        manual_status(:);

    summary.cutoff_status = ...
        cutoff_status(:);

    summary.effective_status = ...
        effective_status(:);

    summary.selected_signal = ...
        char(string( ...
            getappdata(fig,'selected_signal')));

    summary.active_indices = ...
        (1:nCells).';

    summary.n_total = ...
        nCells;

    summary.n_kept_final = ...
        numel(valid_cells);

    summary.n_manual_keep = ...
        sum(manual_status == +1);

    summary.n_manual_excl = ...
        sum(manual_status == -1);

    summary.n_cutoff_keep = ...
        sum(cutoff_status == +1);

    summary.n_cutoff_excl = ...
        sum(cutoff_status == -1);

    %==============================================================
    % Populations
    %==============================================================

    electroporated_indices = [];

    if isappdata(fig,'electroporated_indices')

        electroporated_indices = ...
            getappdata(fig,'electroporated_indices');
    end

    electroporated_indices = ...
        normalize_electroporated_indices( ...
            electroporated_indices, ...
            nCells);

    summary.electroporated_indices = ...
        electroporated_indices(:);

    summary.gcamp_indices = ...
        setdiff( ...
            (1:nCells).', ...
            electroporated_indices, ...
            'stable');

    %==============================================================
    % Commentaire
    %==============================================================

    if isappdata(fig,'comment')
        summary.comment = getappdata(fig,'comment');
    else
        summary.comment = '';
    end
end


function finalize_and_close( ...
        fig, ...
        synchronous_frames)

    confirmed = isappdata(fig,'selection_confirmed') && ...
        getappdata(fig,'selection_confirmed');
    viewer_mode = isappdata(fig,'viewer_mode') && ...
        getappdata(fig,'viewer_mode');
    original = getappdata(fig,'recording_keep_initial');

    % A recording-only decision must not recompute detection or sort.
    if viewer_mode && confirmed && ...
            ~getappdata(fig,'selection_modified') && ...
            ~getappdata(fig,'detection_params_modified')
        setappdata(fig,'selection_confirmed',false);
        confirmed = false;
        if ~isequal(original,getappdata(fig,'recording_keep'))
            setappdata(fig,'recording_keep_metadata_commit',true);
        end
    end

    if viewer_mode && ~confirmed && isempty(original)
        % En Viewer, interroger une seule fois en cas de fermeture normale.
        % Apres une confirmation en cours, la question a deja ete posee.
        % Cancel ferme sans decision ni sauvegarde de statut.
        if isempty(normalize_recording_keep(getappdata(fig,'recording_keep'))) && ...
                ~getappdata(fig,'confirmation_pending')
            ask_recording_keep(fig,'close');
        end
        if ~isempty(normalize_recording_keep(getappdata(fig,'recording_keep')))
            setappdata(fig,'recording_keep_metadata_commit',true);
        end
    end

    %==============================================================
    % STOP ROI MOVIE / TIMER
    %==============================================================

    % Fermer les deux timers et le lecteur TIFF avec le Viewer.
    % La fermeture sans confirmation ne sauvegarde aucune detection.
    reset_roi_movie_display(fig);
    reset_behavior_movie_display(fig,true);


    %==============================================================
    % CONFIRMATION OBLIGATOIRE
    %
    % Fermer avec la croix ne doit JAMAIS produire de nouvelles
    % sorties, en Viewer comme en mode normal.
    %
    % Seul "Confirmer sélection" autorise la sauvegarde.
    %==============================================================

    confirmed = ...
        isappdata(fig,'selection_confirmed') && ...
        getappdata(fig,'selection_confirmed');


    if ~confirmed

        if ishghandle(fig)

            uiresume(fig);
        end

        return;
    end


    %==============================================================
    % MODE
    %==============================================================

    viewer_mode = ...
        isappdata(fig,'viewer_mode') && ...
        getappdata(fig,'viewer_mode');


    %==============================================================
    % VIEWER
    %==============================================================

    if viewer_mode

    [ ...
        invalid_cells, ...
        valid_cells, ...
        DF_sg_selected, ...
        DF_raw_selected, ...
        F0_selected, ...
        noise_est_selected, ...
        Raster_selected, ...
        Acttmp2_selected, ...
        MAct_selected, ...
        thresholds_selected, ...
        summary ...
    ] = ...
        save_viewer_selection( ...
            fig, ...
            synchronous_frames);

    % Confirmer : retrier le DF final, sans retri pendant les exclusions.
    [isort1_selected,isort2_selected,Sm_selected] = ...
        get_confirmed_peak_sort(fig,valid_cells,DF_sg_selected);

    %==========================================================
    % Mise à jour du tableau Excel en mode Viewer
    %==========================================================

    try

        update_cell_selection_summary( ...
            fig, ...
            valid_cells, ...
            invalid_cells);

    catch ME

        warning( ...
            ['Impossible de mettre à jour le tableau ' ...
             'de sélection en mode Viewer : %s'], ...
            ME.message);
    end

    %==========================================================
    % Orig -> new
    %==========================================================

    orig2new = ...
        nan( ...
            max( ...
                [valid_cells(:); 1]), ...
            1);


        %==========================================================
        % Save GUI outputs
        %==========================================================

        setappdata( ...
            fig, ...
            'last_save_outputs', ...
            struct( ...
                'invalid_cells', invalid_cells, ...
                'valid_cells', valid_cells, ...
                'orig2new', orig2new, ...
                'DF_sg', DF_sg_selected, ...
                'DF_raw', DF_raw_selected, ...
                'F0', F0_selected, ...
                'noise_est', noise_est_selected, ...
                'Raster', Raster_selected, ...
                'Acttmp2', {Acttmp2_selected}, ...
                'MAct', MAct_selected, ...
                'thresholds', thresholds_selected, ...
                'opts', getappdata(fig,'opts'), ...
                'isort1_plane', isort1_selected, ...
                'isort2_plane', isort2_selected, ...
                'Sm_plane', Sm_selected, ...
                'summary', summary));


        if ishghandle(fig)

            uiresume(fig);
        end

        return;
    end


    %==============================================================
    % NORMAL MODE
    %
    % On arrive ici UNIQUEMENT après clic sur
    % "Confirmer sélection".
    %==============================================================

    [ ...
        invalid_cells, ...
        valid_cells, ...
        DF, ...
        F0, ...
        noise_est, ...
        Raster, ...
        Acttmp2, ...
        MAct, ...
        thresholds, ...
        opts, ...
        summary ...
    ] = ...
        save_peak_matrix( ...
            fig, ...
            synchronous_frames);


    % Confirmer : retrier le DF final avec les cellules acceptees.
    [isort1_selected,isort2_selected,Sm_selected] = ...
        get_confirmed_peak_sort(fig,valid_cells,DF);

    %==============================================================
    % Table sélection
    %==============================================================

    try

        update_cell_selection_summary( ...
            fig, ...
            valid_cells, ...
            invalid_cells);

    catch ME

        warning( ...
            ['Impossible de mettre à jour le tableau ' ...
             'de sélection : %s'], ...
            ME.message);
    end


    %==============================================================
    % DF RAW sélectionné
    %==============================================================

    DF_raw_all = ...
        getappdata( ...
            fig, ...
            'DF_raw');


    if isfield(summary,'valid_cells') && ...
            ~isempty(summary.valid_cells) && ...
            ~isempty(DF_raw_all)

        DF_raw_selected = ...
            DF_raw_all( ...
                summary.valid_cells, ...
                :);

    else

        DF_raw_selected = [];
    end


    %==============================================================
    % orig2new
    %==============================================================

    orig2new = ...
        nan( ...
            max( ...
                [valid_cells(:); 1]), ...
            1);


    if ~isempty(valid_cells)

        orig2new(valid_cells) = ...
            1:numel(valid_cells);
    end


    %==============================================================
    % Acttmp2 toujours colonne
    %==============================================================

    if iscell(Acttmp2) && ...
            size(Acttmp2,2) > 1

        Acttmp2 = ...
            reshape( ...
                Acttmp2, ...
                [], ...
                1);
    end


    %==============================================================
    % Save GUI outputs
    %==============================================================

    setappdata( ...
        fig, ...
        'last_save_outputs', ...
        struct( ...
            'invalid_cells', invalid_cells, ...
            'valid_cells', valid_cells, ...
            'orig2new', orig2new, ...
            'DF_sg', DF, ...
            'DF_raw', DF_raw_selected, ...
            'F0', F0, ...
            'noise_est', noise_est, ...
            'Raster', Raster, ...
            'Acttmp2', {Acttmp2}, ...
            'MAct', MAct, ...
            'thresholds', thresholds, ...
            'opts', opts, ...
            'isort1_plane', isort1_selected, ...
            'isort2_plane', isort2_selected, ...
            'Sm_plane', Sm_selected, ...
            'summary', summary));


    if ishghandle(fig)

        uiresume(fig);
    end
end

%% ===================== COMMENT =====================

function edit_peak_detection_comment(fig)

    if isempty(fig) || ...
            ~ishghandle(fig)
        return;
    end

    current_comment = '';

    if isappdata(fig,'comment')
        current_comment = getappdata(fig,'comment');
    end

    if isstring(current_comment)
        current_comment = char(current_comment);
    elseif iscell(current_comment) && ~isempty(current_comment)
        current_comment = current_comment{1};
    end

    if isempty(current_comment)
        current_comment = '';
    end

    answer = ...
        inputdlg( ...
            'Commentaire :', ...
            'Modifier le commentaire', ...
            [8 70], ...
            {current_comment});

    % Cancel : ne rien modifier.
    if isempty(answer)
        return;
    end

    new_comment = answer{1};

    if isempty(new_comment)
        new_comment = '';
    end

    if isstring(new_comment)
        new_comment = char(new_comment);
    end

    comment_changed = ...
        ~strcmp( ...
            char(string(current_comment)), ...
            char(string(new_comment)));

    setappdata( ...
        fig, ...
        'comment', ...
        new_comment);

    if comment_changed

        setappdata( ...
            fig, ...
            'comment_modified', ...
            true);
    end

    hComment = ...
        findobj( ...
            fig, ...
            'Tag', ...
            'txt_comment');

    if ~isempty(hComment) && ...
            ishghandle(hComment)

        if isempty(new_comment)
            display_comment = 'Aucun commentaire';
        else
            display_comment = new_comment;
        end

        set( ...
            hComment, ...
            'String', ...
            display_comment);
    end

    update_population_action_buttons(fig);
    drawnow;
end

%% ===================== GUI DISPLAY =====================
function refresh_data(fig)

    DF      = getappdata(fig,'DF_sg');
    F0      = getappdata(fig,'F0');
    cell_id = getappdata(fig,'cell_id');

    ax   = getappdata(fig,'ax1');
    axF0 = getappdata(fig,'axF0');

    hBad = [];
    if isappdata(fig,'hBadPatch_ax1')
        hBad = getappdata(fig,'hBadPatch_ax1');
    end

    kids = allchild(ax);

    %==============================================================
    % Ne conserver que le curseur TEMPOREL COMMUN.
    %==============================================================

    hSharedCursor = getappdata(fig,'shared_movie_cursor');

    keep_kids = false(size(kids));

    if ~isempty(hBad) && isgraphics(hBad)
        keep_kids = keep_kids | (kids == hBad);
    end

    if ~isempty(hSharedCursor) && isgraphics(hSharedCursor)
        keep_kids = keep_kids | (kids == hSharedCursor);
    end

    delete( ...
        kids(~keep_kids));

    hBadF0 = [];

    if isappdata(fig,'hBadPatch_axF0')

        hBadF0 = ...
            getappdata(fig,'hBadPatch_axF0');
    end

    kidsF0 = allchild(axF0);

    hSharedF0 = getappdata(fig,'shared_movie_cursor_f0');
    keepF0 = false(size(kidsF0));

    if ~isempty(hBadF0) && isgraphics(hBadF0)
        keepF0 = keepF0 | (kidsF0 == hBadF0);
    end

    if ~isempty(hSharedF0) && isgraphics(hSharedF0)
        keepF0 = keepF0 | (kidsF0 == hSharedF0);
    end

    delete(kidsF0(~keepF0));

    %==============================================================
    % TRACE DF
    %==============================================================

    x = DF(cell_id,:);
    x = x(:).';

    T = numel(x);

    fs_plane = ...
        getappdata(fig,'fs_plane');

    fs_motion = ...
        getappdata(fig,'fs_motion');

    plane = ...
        getappdata(fig,'plane');

    plane_time_offset = ...
        (plane - 1) / ...
        fs_motion;

    t = ...
        plane_time_offset + ...
        (0:T-1) / fs_plane;

    if T > 1

        xlim(ax,[0 t(end)]);

    else

        xlim( ...
            ax, ...
            [0 max(1/fs_plane, plane_time_offset + 1/fs_plane)]);
    end

    plot( ...
        ax, ...
        t, ...
        x, ...
        'k-');

    hold(ax,'on');

    % La trace est sous le raster, le temps figure sur Motion en bas.
    set(ax,'XTickLabel',[]);
    xlabel(ax,'');

    %==============================================================
    % TRACE F0
    %==============================================================

    if ~isempty(F0) && ...
            cell_id >= 1 && ...
            cell_id <= size(F0,1)

        f0 = ...
            F0(cell_id,:);

    else

        f0 = [];
    end

    if ~isempty(f0)

        f0 = ...
            f0(:).';

        L = ...
            min( ...
                numel(t), ...
                numel(f0));

        t_f0 = ...
            t(1:L);

        f0 = ...
            f0(1:L);

        if T > 1

            xlim(axF0,[0 t(end)]);

        else

            xlim( ...
                axF0, ...
                [0 max(1/fs_plane, plane_time_offset + 1/fs_plane)]);
        end

        plot( ...
            axF0, ...
            t_f0, ...
            f0, ...
            'b-');

        % Echelle Y independante, ajustee a la cellule courante.
        % Les NaN/Inf ne doivent pas fausser les bornes.
        f0_finite = f0(isfinite(f0));

        if isempty(f0_finite)
            ylim(axF0,[-1 1]);
        else
            f0_min = min(f0_finite);
            f0_max = max(f0_finite);
            f0_span = f0_max - f0_min;

            if f0_span <= 0
                f0_pad = max(0.05*abs(f0_min),1e-3);
            else
                f0_pad = 0.08*f0_span;
            end

            ylim(axF0,[f0_min-f0_pad f0_max+f0_pad]);
        end

        if ~isempty(hBadF0) && ...
                isgraphics(hBadF0) && ...
                isappdata(fig,'focus_segs_time')

            focus_segs_time = ...
                getappdata( ...
                    fig, ...
                    'focus_segs_time');

            update_badframe_patch( ...
                hBadF0, ...
                focus_segs_time, ...
                ylim(axF0));

            uistack( ...
                hBadF0, ...
                'bottom');
        end

        ylabel(axF0,'F0');

    else

        cla(axF0);

        text( ...
            axF0, ...
            0.5, ...
            0.5, ...
            'F0 indisponible', ...
            'Units','normalized', ...
            'HorizontalAlignment','center');

        set( ...
            axF0, ...
            'XTickLabel',[]);
    end

    %==============================================================
    % LIBELLES
    %==============================================================

    ylabel(ax,'\DeltaF/F raw (SavGol)');

    %==============================================================
    % SEUIL
    %==============================================================

    if isappdata(fig,'seuil_detection_last')

        seuil_detection = ...
            getappdata( ...
                fig, ...
                'seuil_detection_last');

        if isfinite(seuil_detection)

            if T > 1

                x_end = ...
                    t(end);

            else

                x_end = ...
                    plane_time_offset + ...
                    1/fs_plane;
            end

            plot( ...
                ax, ...
                [plane_time_offset x_end], ...
                [seuil_detection seuil_detection], ...
                ':', ...
                'Color',[.7 .1 .1], ...
                'LineWidth',1);
        end
    end

    %==============================================================
    % PICS
    %==============================================================

    if isappdata(fig,'auto_peaks')

        pk = ...
            getappdata( ...
                fig, ...
                'auto_peaks');

        pk = ...
            pk(:).';

        pk = ...
            pk( ...
                isfinite(pk) & ...
                pk >= 1 & ...
                pk <= T);

        if ~isempty(pk)

            t_pk = ...
                plane_time_offset + ...
                (pk-1) / fs_plane;

            plot( ...
                ax, ...
                t_pk, ...
                x(pk), ...
                '*', ...
                'Color',[0.85 0.1 0.1], ...
                'MarkerSize',5, ...
                'LineWidth',1);
        end
    end

    %==============================================================
    % ECHELLE VERTICALE AUTOMATIQUE DE LA CELLULE COURANTE
    %
    % Inclure toutes les valeurs finies de DF et le seuil de
    % detection (s'il est affiche), sans tronquer les grands pics.
    % Fixer YLim a chaque changement de cellule : l'ancienne echelle
    % ne doit pas etre reutilisee pour la cellule suivante.
    %==============================================================

    y_values = x(isfinite(x));

    if isappdata(fig,'seuil_detection_last')
        threshold_display = getappdata(fig,'seuil_detection_last');

        if isscalar(threshold_display) && ...
                isfinite(threshold_display)

            y_values(end+1) = threshold_display;
        end
    end

    if isempty(y_values)
        ylim(ax,[-1 1]);
    else
        y_min = min(y_values);
        y_max = max(y_values);
        y_span = y_max - y_min;

        if y_span <= 0
            % Trace constante : assurer une hauteur visible.
            padding = max(0.1 * abs(y_min),1e-3);
            ylim(ax,[y_min-padding y_max+padding]);
        else
            % Une marge haute plus grande laisse aussi respirer les pics.
            ylim(ax,[y_min-0.10*y_span y_max+0.15*y_span]);
        end
    end

    % Adapter les zones des frames exclues a la NOUVELLE echelle,
    % et les garder derriere la trace et les marqueurs de pics.
    if ~isempty(hBad) && ...
            isgraphics(hBad) && ...
            isappdata(fig,'focus_segs_time')

        update_badframe_patch( ...
            hBad, ...
            getappdata(fig,'focus_segs_time'), ...
            ylim(ax));

        uistack(hBad,'bottom');
    end

    %==============================================================
    % MODE VIEWER
    %==============================================================

    viewer_mode = ...
        isappdata(fig,'viewer_mode') && ...
        getappdata(fig,'viewer_mode');

    %==============================================================
    % CELLULE ÉLECTROPORÉE
    %==============================================================

    is_electroporated_cell = ...
        false;

    if isappdata(fig,'electroporated_indices')

        electroporated_indices = ...
            getappdata( ...
                fig, ...
                'electroporated_indices');

        if ~isempty(electroporated_indices)

            electroporated_indices = ...
                electroporated_indices(:);

            electroporated_indices = ...
                electroporated_indices( ...
                    isfinite( ...
                        electroporated_indices));

            is_electroporated_cell = ...
                any( ...
                    round(electroporated_indices) == ...
                    round(cell_id));
        end
    end

    if is_electroporated_cell

        text( ...
            ax, ...
            0.72, ...
            0.95, ...
            'ÉLECTROPORÉE', ...
            'Units','normalized', ...
            'Color',[0.1 0.2 0.9], ...
            'FontWeight','bold', ...
            'FontSize',12, ...
            'VerticalAlignment','top', ...
            'BackgroundColor',[1 1 1 0.6], ...
            'Margin',4);
    end

    %==============================================================
    % STATUT CELLULE
    %==============================================================

    label_txt = '';
    label_color = [0 0 0];

    %==============================================================
    % VIEWER :
    % reconstruire raison d'exclusion à partir des données sauvegardées
    %==============================================================

    if viewer_mode

    %==========================================================
    % Statuts sauvegardés
    %==========================================================

    manual_status = ...
        getappdata( ...
            fig, ...
            'manual_status');

    cutoff_status = ...
        getappdata( ...
            fig, ...
            'cutoff_status');

    valid_cells_saved = [];

    if isappdata(fig,'valid_cells_saved')

        valid_cells_saved = ...
            getappdata( ...
                fig, ...
                'valid_cells_saved');
    end

    is_valid_saved = ...
        false;
    
    if ~isempty(valid_cells_saved)
    
        valid_cells_saved = ...
            round( ...
                double( ...
                    valid_cells_saved(:)));
    
        is_valid_saved = ...
            any( ...
                valid_cells_saved == cell_id);
    end

    %==========================================================
    % 1. DÉCISION MANUELLE
    % Priorité absolue
    %==========================================================

    if cell_id <= numel(manual_status) && ...
            manual_status(cell_id) == -1

        label_txt = ...
            'CELLULE EXCLUE (manuel)';

        label_color = ...
            [0.85 0.1 0.1];

    elseif cell_id <= numel(manual_status) && ...
            manual_status(cell_id) == +1

        label_txt = ...
            'CELLULE CONSERVÉE (manuel)';

        label_color = ...
            [0.1 0.6 0.1];

    %==========================================================
    % 2. CELLULE CONSERVÉE
    %==========================================================

    elseif is_valid_saved

        label_txt = ...
            'CELLULE CONSERVÉE';

        label_color = ...
            [0.1 0.6 0.1];

    %==========================================================
    % 3. CELLULE EXCLUE AUTOMATIQUEMENT
    %==========================================================

    else

        reasons = {};

        n_peaks_current = ...
            NaN;

        if isappdata(fig,'n_peaks_all')

            n_peaks_all = ...
                getappdata( ...
                    fig, ...
                    'n_peaks_all');

            if ~isempty(n_peaks_all) && ...
                    cell_id <= numel(n_peaks_all)

                n_peaks_current = ...
                    n_peaks_all(cell_id);
            end
        end

        opts = ...
            getappdata( ...
                fig, ...
                'opts');

        %------------------------------------------------------
        % Nombre de pics
        %------------------------------------------------------

        if isfinite(n_peaks_current)

            if n_peaks_current == 0

                reasons{end+1} = ...
                    '0 pics';

            elseif n_peaks_current < ...
                    opts.min_n_peaks_cutoff

                reasons{end+1} = ...
                    sprintf( ...
                        'pics %d < %d', ...
                        n_peaks_current, ...
                        opts.min_n_peaks_cutoff);
            end
        end

        %------------------------------------------------------
        % Taille du masque
        %------------------------------------------------------

        if isappdata(fig,'mask_sizes')

            mask_sizes = ...
                getappdata( ...
                    fig, ...
                    'mask_sizes');

            if ~isempty(mask_sizes) && ...
                    cell_id <= numel(mask_sizes) && ...
                    isfinite(mask_sizes(cell_id)) && ...
                    mask_sizes(cell_id) < opts.min_mask_um2

                reasons{end+1} = ...
                    sprintf( ...
                        'masque %.1f < %.1f um²', ...
                        mask_sizes(cell_id), ...
                        opts.min_mask_um2);
            end
        end

        %------------------------------------------------------
        % Connectivité
        %------------------------------------------------------

        if isappdata(fig,'mask_connectivity_ratio')

            mask_connectivity_ratio = ...
                getappdata( ...
                    fig, ...
                    'mask_connectivity_ratio');

            if ~isempty(mask_connectivity_ratio) && ...
                    cell_id <= numel(mask_connectivity_ratio) && ...
                    isfinite(mask_connectivity_ratio(cell_id)) && ...
                    mask_connectivity_ratio(cell_id) < ...
                    opts.min_mask_connectivity

                reasons{end+1} = ...
                    sprintf( ...
                        'connectivité %.2f < %.2f', ...
                        mask_connectivity_ratio(cell_id), ...
                        opts.min_mask_connectivity);
            end
        end

        %------------------------------------------------------
        % Si cutoff_status dit rejetée mais qu'on n'arrive pas
        % à reconstruire le critère
        %------------------------------------------------------

        if isempty(reasons) && ...
                cell_id <= numel(cutoff_status) && ...
                cutoff_status(cell_id) == -1

            reasons{end+1} = ...
                'cutoff';
        end

        %------------------------------------------------------
        % Texte final
        %------------------------------------------------------

        if isempty(reasons)

            label_txt = ...
                'CELLULE EXCLUE';

        else

            label_txt = ...
                sprintf( ...
                    'CELLULE EXCLUE (%s)', ...
                    strjoin( ...
                        reasons, ...
                        ', '));
        end

        label_color = ...
            [0.85 0.1 0.1];
    end

    %==============================================================
    % MODE NORMAL
    %==============================================================

    else

        manual_status = ...
            getappdata( ...
                fig, ...
                'manual_status');

        cutoff_status = ...
            getappdata( ...
                fig, ...
                'cutoff_status');

        n_peaks_all = [];

        if isappdata(fig,'n_peaks_all')

            n_peaks_all = ...
                getappdata( ...
                    fig, ...
                    'n_peaks_all');
        end

        %==========================================================
        % MANUEL : priorité absolue
        %==========================================================

        if cell_id <= numel(manual_status) && ...
                manual_status(cell_id) == +1

            label_txt = ...
                'CELLULE CONSERVÉE (manuel)';

            label_color = ...
                [0.1 0.6 0.1];

        elseif cell_id <= numel(manual_status) && ...
                manual_status(cell_id) == -1

            label_txt = ...
                'CELLULE EXCLUE (manuel)';

            label_color = ...
                [0.85 0.1 0.1];

        %==========================================================
        % CUTOFF
        %==========================================================

        elseif cell_id <= numel(cutoff_status) && ...
                cutoff_status(cell_id) == -1

            reasons = {};

            opts = ...
                getappdata( ...
                    fig, ...
                    'opts');

            %------------------------------------------------------
            % Pics
            %------------------------------------------------------

            if ~isempty(n_peaks_all) && ...
                    cell_id <= numel(n_peaks_all)

                n_peaks_current = ...
                    n_peaks_all(cell_id);

                if n_peaks_current == 0

                    reasons{end+1} = ...
                        '0 pics';

                elseif n_peaks_current < ...
                        opts.min_n_peaks_cutoff

                    reasons{end+1} = ...
                        sprintf( ...
                            'pics < %d', ...
                            opts.min_n_peaks_cutoff);
                end
            end

            %------------------------------------------------------
            % Taille masque
            %------------------------------------------------------

            if isappdata(fig,'mask_sizes')

                mask_sizes = ...
                    getappdata( ...
                        fig, ...
                        'mask_sizes');

                if ~isempty(mask_sizes) && ...
                        cell_id <= numel(mask_sizes) && ...
                        isfinite(mask_sizes(cell_id)) && ...
                        mask_sizes(cell_id) < opts.min_mask_um2

                    reasons{end+1} = ...
                        sprintf( ...
                            'masque %.1f < %.1f um²', ...
                            mask_sizes(cell_id), ...
                            opts.min_mask_um2);
                end
            end

            %------------------------------------------------------
            % Connectivité
            %------------------------------------------------------

            if isappdata(fig,'mask_connectivity_ratio')

                mask_connectivity_ratio = ...
                    getappdata( ...
                        fig, ...
                        'mask_connectivity_ratio');

                if ~isempty(mask_connectivity_ratio) && ...
                        cell_id <= numel(mask_connectivity_ratio) && ...
                        isfinite(mask_connectivity_ratio(cell_id)) && ...
                        mask_connectivity_ratio(cell_id) < ...
                        opts.min_mask_connectivity

                    reasons{end+1} = ...
                        sprintf( ...
                            'connectivité %.2f < %.2f', ...
                            mask_connectivity_ratio(cell_id), ...
                            opts.min_mask_connectivity);
                end
            end

            if isempty(reasons)

                label_txt = ...
                    'CELLULE EXCLUE (cutoff)';

            else

                label_txt = ...
                    sprintf( ...
                        'CELLULE EXCLUE (%s)', ...
                        strjoin( ...
                            reasons, ...
                            ', '));
            end

            label_color = ...
                [0.85 0.1 0.1];

        elseif cell_id <= numel(cutoff_status) && ...
                cutoff_status(cell_id) == +1

            label_txt = ...
                'CELLULE CONSERVÉE';

            label_color = ...
                [0.1 0.6 0.1];

        elseif ~isempty(n_peaks_all) && ...
                cell_id <= numel(n_peaks_all) && ...
                n_peaks_all(cell_id) == 0

            label_txt = ...
                'CELLULE EXCLUE (0 pics)';

            label_color = ...
                [0.6 0.6 0.6];
        end
    end

    %==============================================================
    % AFFICHAGE LABEL
    %==============================================================

    if ~isempty(label_txt)

        text( ...
            ax, ...
            0.02, ...
            0.95, ...
            label_txt, ...
            'Units','normalized', ...
            'Color',label_color, ...
            'FontWeight','bold', ...
            'FontSize',12, ...
            'VerticalAlignment','top', ...
            'BackgroundColor',[1 1 1 0.6], ...
            'Margin',4);
    end

    % Les identifiants sont dans le panneau Navigation, pas sur la trace.
    update_navigation_identification(fig);

    % cla(axF0) peut detruire sa ligne : la recreer au besoin.
    update_shared_movie_cursor(fig,getappdata(fig,'shared_movie_time'));
    % Deplacer uniquement la fleche exterieure sur la ligne courante,
    % sans recalculer ni recolorer les activites du raster.
    update_current_cell_raster_arrow(fig);
    if getappdata(fig,'viewer_mode')
        update_viewer_roi_zoom(fig);
    else
        update_roi_zoom(fig);
    end
    % L'axe ROI est partage avec le film ; l'eventuel ancien handle
    % image est detruit par cla() lors du changement de cellule.
    setappdata(fig,'roi_movie_hImg',[]);
end

%% ===================== TRI DU RASTER : CACHE PAR INDICES ORIGINAUX =====================

function tf = is_valid_peak_permutation(indices,n)
    tf = isnumeric(indices) && isvector(indices) && ...
        numel(indices)==n && all(isfinite(indices(:))) && ...
        all(indices(:)==round(indices(:))) && ...
        isequal(sort(double(indices(:))),(1:n)');
end

function initialize_peak_raster_sort(fig,source_ids,isort1,isort2,Sm,viewer_mode)
    % source_ids est dans le meme ordre que les lignes du DF source.
    source_ids = source_ids(:);
    n = numel(source_ids);
    if ~viewer_mode && n>0
        DF = getappdata(fig,'DF_sg');
        ops = getappdata(fig,'ops');
        try
            [isort1,isort2,Sm] = raster_processing(double(DF(source_ids,:)),ops);
        catch ME
            warning('peak_detection_tuner:rasterSort', ...
                'Tri du raster indisponible (%s). Ordre original utilise.',ME.message);
            isort1 = []; isort2 = []; Sm = [];
        end
    end
    if ~is_valid_peak_permutation(isort1,n)
        if viewer_mode && n>0
            warning('peak_detection_tuner:missingSort', ...
                'isort1 sauvegarde absent ou invalide : ordre original conserve, sans retrier.');
        end
        % Sans permutation fiable, l'orientation des lignes de Sm est
        % inconnue : ne pas sauvegarder de matrice desynchronisee.
        Sm = [];
        isort1 = (1:n)';
    else
        isort1 = isort1(:);
    end
    if ~isempty(isort2) && ~is_valid_peak_permutation(isort2,n)
        isort2 = [];
    end
    setappdata(fig,'peak_sort_source_ids',source_ids);
    setappdata(fig,'peak_sort_isort1',isort1);
    setappdata(fig,'peak_sort_isort2',isort2);
    setappdata(fig,'peak_sort_Sm',Sm);
    setappdata(fig,'peak_sort_order_ids',source_ids(isort1));
    setappdata(fig,'peak_sort_initialized',true);
    setappdata(fig,'peak_sort_df_changed',false);
end

function ids = sorted_original_peak_ids(fig,kept_ids)
    % Un rejet est seulement un filtre logique sur l'ordre deja calcule.
    % Une reintegration restaure sa position ; une nouvelle cellule est
    % ajoutee a la fin, sans recalculer le tri des autres cellules.
    kept_ids = kept_ids(:);
    order = getappdata(fig,'peak_sort_order_ids');
    if isempty(order)
        ids = kept_ids;
        return;
    end
    ids = order(ismember(order,kept_ids));
    ids = [ids(:);kept_ids(~ismember(kept_ids,order))];
end

function [isort1,isort2,Sm] = get_confirmed_peak_sort(fig,valid_cells,DF_final)
    % Uniquement APRES CONFIRMATION : calculer sur le DF final.
    % isort1/isort2 referencent les LIGNES de DF_final, dont l'ordre
    % correspond exactement a valid_cells (IDs originaux des cellules).
    valid_cells = valid_cells(:);
    n = numel(valid_cells);
    isort1 = []; isort2 = []; Sm = [];
    if size(DF_final,1) ~= n
        error('peak_detection_tuner:sortRowMismatch', ...
            'DF final : %d lignes pour %d cellules acceptees.', ...
            size(DF_final,1),n);
    end
    if n==0
        return;
    end

    try
        ops = getappdata(fig,'ops');
        [isort1,isort2,Sm] = ...
            raster_processing(double(DF_final),ops);
        if ~is_valid_peak_permutation(isort1,n)
            error('peak_detection_tuner:invalidSort', ...
                'raster_processing ne renvoie pas une permutation isort1 valide.');
        end
        isort1 = isort1(:);
        if ~isempty(isort2)
            if is_valid_peak_permutation(isort2,n)
                isort2 = isort2(:);
            else
                warning('peak_detection_tuner:invalidSort2', ...
                    'isort2 invalide : sortie secondaire vide.');
                isort2 = [];
            end
        end
    catch ME
        % Ne pas perdre une selection confirmee si le calcul echoue.
        % Remapper l'ordre visible sur les lignes du DF final, et vider
        % Sm/isort2 : ils peuvent ne plus correspondre aux signaux gardes.
        warning('peak_detection_tuner:confirmedSort', ...
            'Tri final indisponible (%s) ; ordre affiche conserve.',ME.message);
        ids_sorted = sorted_original_peak_ids(fig,valid_cells);
        [present,isort1] = ismember(ids_sorted,valid_cells);
        if ~all(present) || ~is_valid_peak_permutation(isort1,n)
            isort1 = (1:n)';
        else
            isort1 = isort1(:);
        end
        isort2 = [];
        Sm = [];
    end
end

%% ===================== RASTER DES PICS VIEWER =====================

function refresh_peak_raster(fig)
    % Affiche les pics des cellules acceptees selon l'ordre trie mis en
    % cache, en mode Viewer ou avant confirmation de detection initiale.
    % Ne modifie jamais les fichiers MAT.
    if ~ishghandle(fig)
        return;
    end

    ax = getappdata(fig,'axRaster');
    if isempty(ax) || ~isgraphics(ax,'axes')
        return;
    end

    raster_all = getappdata(fig,'Raster_saved');
    if isempty(raster_all) || ~ismatrix(raster_all)
        setappdata(fig,'raster_display_original_ids',[]);
        update_current_cell_raster_arrow(fig);
        cla(ax);
        text(ax,0.5,0.5,'Raster indisponible', ...
            'Units','normalized','HorizontalAlignment','center');
        update_peak_raster_title(fig);
        return;
    end

    nCells = size(raster_all,1);
    nFrames = size(raster_all,2);
    % Viewer : valid_cells sauvegardees + corrections manuelles.
    % Nouvelle detection : cutoff effectif + corrections manuelles.
    kept = get_navigation_kept_mask(fig,nCells, ...
        getappdata(fig,'viewer_mode'));
    % Meme mode d'affichage que la barre de navigation. Le raster du plan
    % conserve toutes les cellules acceptees, meme si une sous-population
    % est choisie pour la navigation.
    original_ids = sort_cell_ids_for_display(fig,find(kept));
    nKept = numel(original_ids);
    setappdata(fig,'raster_display_original_ids',original_ids);

    fs_plane = getappdata(fig,'fs_plane');
    fs_motion = getappdata(fig,'fs_motion');
    plane = getappdata(fig,'plane');
    plane_offset = (plane-1)/fs_motion;

    cla(ax);
    hold(ax,'on');

    if nKept>0 && nFrames>0
        % Une ligne graphique unique : nettement plus rapide qu'un objet
        % par pic. Les rangs Y sont compacts ; les ticks sont des ID
        % originaux, pas des indices de la matrice reduite sauvegardee.
        [rank, frame] = find(raster_all(original_ids,:));
        if ~isempty(frame)
            t = plane_offset + (double(frame(:)')-1)/fs_plane;
            y = double(rank(:)');
            xp = reshape([t;t;nan(size(t))],[],1);
            yp = reshape([y-0.33;y+0.33;nan(size(y))],[],1);
            line(ax,xp,yp,'Color',[0 0 0],'LineWidth',0.5, ...
                'HitTest','off','PickableParts','none');
        end
        ylim(ax,[0.5 nKept+0.5]);
        ticks = unique(round(linspace(1,nKept,min(8,nKept))));
        set(ax,'YTick',ticks, ...
            'YTickLabel',cellstr(num2str(original_ids(ticks))), ...
            'YDir','reverse');
    else
        ylim(ax,[0.5 1.5]);
        set(ax,'YTick',[],'YDir','reverse');
        text(ax,0.5,0.5,'Aucune cellule retenue', ...
            'Units','normalized','HorizontalAlignment','center', ...
            'Tag','raster_empty_label');
    end

    % Echelle absolue, comprenant le decalage d'acquisition du plan.
    t_end = plane_offset + max(0,nFrames-1)/fs_plane;
    if nFrames>1
        xlim(ax,[0 t_end]);
    else
        xlim(ax,[0 max(1/fs_plane,t_end+1/fs_plane)]);
    end
    % Une seule echelle temporelle lisible tout en bas du Viewer.
    set(ax,'XTickLabel',[]);
    xlabel(ax,'');
    ylabel(ax,'Cellule (ID)');
    box(ax,'on');
    hold(ax,'off');
    setappdata(fig,'raster_display_cell_count',nKept);
    update_peak_raster_title(fig);

    % Le raster est efface puis reconstruit avec cla() : recreer aussi
    % les zones badframes, dans le meme referentiel temporel que DF/F0.
    refresh_raster_badframe_patch(fig);

    % cla() efface la ligne du raster uniquement : recreer le marqueur
    % temporel commun sur les cinq axes au meme instant, sans seek film.
    update_shared_movie_cursor(fig,getappdata(fig,'shared_movie_time'));
    update_current_cell_raster_arrow(fig);
end

function update_current_cell_raster_arrow(fig)
    % Une fleche a DROITE du raster indique la ligne de la cellule
    % courante. Aucune recoloration des pics et aucun tick supplementaire.
    % Une cellule rejetee n'a pas de ligne dans le raster : pas de fleche.
    % Position calculee depuis YLim/YDir : elle suit le zoom et disparait
    % si la ligne courante n'est plus visible dans les limites des axes.
    if ~ishghandle(fig)
        return;
    end

    old = [];
    if isappdata(fig,'hCurrentCellRasterArrow')
        old = getappdata(fig,'hCurrentCellRasterArrow');
    end

    % Nettoyer aussi les surlignages d'une ancienne version de l'interface.
    if ~isappdata(fig,'axRaster')
        if ~isempty(old) && isgraphics(old), delete(old); end
        setappdata(fig,'hCurrentCellRasterArrow',[]);
        return;
    end
    ax = getappdata(fig,'axRaster');
    if isempty(ax) || ~isgraphics(ax,'axes')
        if ~isempty(old) && isgraphics(old), delete(old); end
        setappdata(fig,'hCurrentCellRasterArrow',[]);
        return;
    end
    old_peaks = findobj(ax,'Tag','current_cell_raster_peaks');
    if ~isempty(old_peaks)
        delete(old_peaks);
    end

    if ~isappdata(fig,'cell_id') || ...
            ~isappdata(fig,'raster_display_original_ids')
        if ~isempty(old) && isgraphics(old), delete(old); end
        setappdata(fig,'hCurrentCellRasterArrow',[]);
        return;
    end

    cid = getappdata(fig,'cell_id');
    ids = getappdata(fig,'raster_display_original_ids');
    if isempty(cid) || ~isscalar(cid) || ~isfinite(cid) || isempty(ids)
        if ~isempty(old) && isgraphics(old), delete(old); end
        setappdata(fig,'hCurrentCellRasterArrow',[]);
        return;
    end

    row = find(ids==round(cid),1);
    if isempty(row)
        if ~isempty(old) && isgraphics(old), delete(old); end
        setappdata(fig,'hCurrentCellRasterArrow',[]);
        return;
    end

    % Annotation en coordonnees normalisees de la figure : la fleche reste
    % a droite du raster meme si les axes temporels sont zoomes/deplaces.
    % La transformation prend en compte les limites Y du zoom courant.
    yl = get(ax,'YLim');
    if any(~isfinite(yl)) || yl(2)<=yl(1) || ...
            row<yl(1) || row>yl(2)
        if ~isempty(old) && isgraphics(old), delete(old); end
        setappdata(fig,'hCurrentCellRasterArrow',[]);
        return;
    end

    pos = get(ax,'Position'); % axes en Units='normalized'
    xRight = pos(1)+pos(3);
    fraction = (row-yl(1))/(yl(2)-yl(1));
    if strcmp(get(ax,'YDir'),'reverse')
        fraction = 1-fraction;
    end
    yRow = pos(2)+pos(4)*fraction;
    xArrow = [xRight+0.018 xRight+0.002];
    yArrow = [yRow yRow];

    if ~isempty(old) && isgraphics(old)
        set(old,'X',xArrow,'Y',yArrow);
    else
        hArrow = annotation(fig,'arrow',xArrow,yArrow, ...
            'Color',[0.10 0.35 0.85], ...
            'LineWidth',1.8, ...
            'HeadLength',7, ...
            'HeadWidth',7);
        setappdata(fig,'hCurrentCellRasterArrow',hArrow);
    end
end

function refresh_raster_badframe_patch(fig)
    % Reutilise les segments en secondes deja traces sur DF, F0 et Dev.
    % N'affecte ni le Raster sauvegarde ni la selection des cellules.
    ax = getappdata(fig,'axRaster');
    if isempty(ax) || ~isgraphics(ax,'axes')
        return;
    end

    h = getappdata(fig,'hBadPatch_axRaster');
    segs = getappdata(fig,'focus_segs_time');

    if isempty(segs)
        if ~isempty(h) && isgraphics(h)
            delete(h);
        end
        setappdata(fig,'hBadPatch_axRaster',[]);
        return;
    end

    if isempty(h) || ~isgraphics(h)
        % patch() effacerait le raster si NextPlot='replace' (hold off).
        % Preserver les pics deja traces et l'etat initial de l'axe.
        was_held = ishold(ax);
        hold(ax,'on');
        h = create_badframe_patch(ax,segs);
        if ~was_held
            hold(ax,'off');
        end
        set(h,'Tag','raster_badframe_patch', ...
            'HitTest','off','PickableParts','none');
        setappdata(fig,'hBadPatch_axRaster',h);
    else
        update_badframe_patch(h,segs,ylim(ax));
    end

    % Toujours derriere les pics noirs et les points rouges courants.
    uistack(h,'bottom');
end

function update_peak_raster_title(fig)
    if ~ishghandle(fig)
        return;
    end
    ax = getappdata(fig,'axRaster');
    if isempty(ax) || ~isgraphics(ax,'axes')
        return;
    end
    plane = getappdata(fig,'plane');
    nKept = getappdata(fig,'raster_display_cell_count');
    if isempty(nKept)
        nKept = 0;
    end
    caption = sprintf('Raster trie des pics | plan %d | %d cellules retenues', ...
        plane-1,nKept);
    if getappdata(fig,'viewer_mode') && ...
            getappdata(fig,'detection_params_modified')
        caption = [caption ' | pics sauvegardes (recalcul complet a confirmer)'];
    end
    title(ax,caption,'Interpreter','none','FontSize',10);
end

function h = create_badframe_patch(ax, segs)
    if isempty(segs) || isempty(ax) || ~ishghandle(ax)
        h = gobjects(1);
        return;
    end

    yl = ylim(ax);
    [X, Y] = segs_to_patchXY(segs, yl);

    h = patch(ax, X, Y, [1 0 0], ...
        'FaceAlpha', 0.25, ...
        'EdgeColor', 'none', ...
        'HitTest', 'off');

    set(h,'XLimInclude','off','YLimInclude','off');
    uistack(h,'bottom');
end

function update_badframe_patch(h, segs, yl)
    if isempty(h) || ~isgraphics(h) || isempty(segs) || numel(yl)~=2
        return;
    end
    [X, Y] = segs_to_patchXY(segs, yl);
    set(h, 'XData', X, 'YData', Y);
end

function [X, Y] = segs_to_patchXY(segs, yl)
    y0 = yl(1); y1 = yl(2);

    n = size(segs,1);
    X = nan(1, 5*n);
    Y = nan(1, 5*n);

    for k = 1:n
        a = segs(k,1);
        b = segs(k,2);

        ii = (k-1)*5 + (1:5);
        X(ii) = [a b b a a];
        Y(ii) = [y0 y0 y1 y1 y0];
    end
end


function update_viewer_roi_zoom(fig)
    % Image moyenne recadree sur la cellule active dans le Viewer.
    % Image moyenne dans le Viewer : elle utilise le meme axe que le
    % film ROI, mais sans modifier les timers ni les indices de frames.
    if ~ishghandle(fig) || ~isappdata(fig,'axViewerROI')
        return;
    end

    ax = getappdata(fig,'axViewerROI');
    if isempty(ax) || ~isgraphics(ax,'axes')
        return;
    end

    % La navigation peut avoir ete temporairement vide : restaurer l'axe.
    set(ax,'Visible','on');
    meanImg = getappdata(fig,'meanImg');
    if isempty(meanImg) || ~ismatrix(meanImg) || ...
            ~(isnumeric(meanImg) || islogical(meanImg))
        cla(ax);
        title(ax,'ROI indisponible');
        return;
    end

    cid = getappdata(fig,'cell_id');
    masks = getappdata(fig,'masks');
    mask = [];
    if ~isempty(cid) && isscalar(cid) && isfinite(cid) && ...
            ~isempty(masks) && ...
            (isnumeric(masks) || islogical(masks)) && ...
            ndims(masks)>=3 && cid>=1 && cid<=size(masks,1)
        mask = squeeze(masks(round(cid),:,:)) > 0;
    end

    if isempty(mask) || ~isequal(size(mask),size(meanImg)) || ...
            ~any(mask(:))
        cla(ax);
        imagesc(ax,double(meanImg));
        colormap(ax,gray);
        axis(ax,'image');
        set(ax,'YDir','reverse','XTick',[],'YTick',[]);
        title(ax,'ROI | masque indisponible');
        return;
    end

    [y,x] = find(mask);
    pad = 12;
    xmin = max(1,min(x)-pad);
    xmax = min(size(meanImg,2),max(x)+pad);
    ymin = max(1,min(y)-pad);
    ymax = min(size(meanImg,1),max(y)+pad);

    % Toujours actualiser le crop de la cellule courante ; la video
    % emploie exactement ces bornes lors de la prochaine lecture.
    setappdata(fig,'roi_crop_bounds',[xmin xmax ymin ymax]);

    crop = double(meanImg(ymin:ymax,xmin:xmax));
    cla(ax);
    imagesc(ax,crop);
    colormap(ax,gray);
    axis(ax,'image');
    set(ax,'YDir','reverse','XTick',[],'YTick',[]);

    finite_values = crop(isfinite(crop));
    if ~isempty(finite_values)
        lo = prctile(finite_values,5);
        hi = prctile(finite_values,99.5);
        if ~isfinite(lo) || ~isfinite(hi) || hi<=lo
            lo = min(finite_values);
            hi = max(finite_values);
        end
        if isfinite(lo) && isfinite(hi)
            if hi<=lo
                hi = lo+max(1,abs(lo)*1e-3);
            end
            caxis(ax,[lo hi]);
        end
    end

    hold(ax,'on');

    % Tracer les vrais outlines en priorite (coordonnees MATLAB 1-based).
    % S'ils sont absents, extraire le contour du masque de la ROI.
    has_outline = false;
    outlines_x = getappdata(fig,'outlines_x');
    outlines_y = getappdata(fig,'outlines_y');
    if iscell(outlines_x) && iscell(outlines_y) && ...
            cid<=numel(outlines_x) && cid<=numel(outlines_y)
        xx = double(outlines_x{cid}(:));
        yy = double(outlines_y{cid}(:));
        n = min(numel(xx),numel(yy));
        if n>0
            xx = xx(1:n);
            yy = yy(1:n);
            good = isfinite(xx) & isfinite(yy);
            xx = xx(good);
            yy = yy(good);
            if ~isempty(xx)
                plot(ax,xx-xmin+1,yy-ymin+1,'r-','LineWidth',1.5);
                has_outline = true;
            end
        end
    end

    if ~has_outline
        mask_crop = mask(ymin:ymax,xmin:xmax);
        boundaries = bwboundaries(mask_crop,'noholes');
        for k = 1:numel(boundaries)
            b = boundaries{k};
            plot(ax,b(:,2),b(:,1),'r-','LineWidth',1.5);
        end
    end

    pixel_size_um = getappdata(fig,'pixel_size_um');
    add_scale_bar(ax,pixel_size_um);
    % Conserver le meme titre que pendant le film, y compris a la pause :
    % seule l'image affichee redevient l'image moyenne avec son contour.
    update_viewer_roi_title(fig);
    hold(ax,'off');
end

function update_viewer_roi_title(fig)
    % Affiche l'identifiant et, si le film ROI est indexe, la frame
    % correspondant au curseur temporel commun. N'affiche jamais le type
    % d'image (film ou moyenne) : la pause ne change donc pas le titre.
    if isempty(fig) || ~ishghandle(fig) || ...
            ~isappdata(fig,'axViewerROI')
        return;
    end

    ax = getappdata(fig,'axViewerROI');
    if isempty(ax) || ~isgraphics(ax,'axes') || ...
            ~isappdata(fig,'cell_id')
        return;
    end

    cid = getappdata(fig,'cell_id');
    if isempty(cid) || ~isscalar(cid) || ~isfinite(cid)
        return;
    end

    title_text = sprintf('Cellule %d',round(cid));
    movie_data = getappdata(fig,'roi_movie_data');

    if isstruct(movie_data) && isfield(movie_data,'nFrames') && ...
            isscalar(movie_data.nFrames) && ...
            isfinite(movie_data.nFrames) && movie_data.nFrames >= 1

        frame_idx = getappdata(fig,'roi_movie_frame');
        t = getappdata(fig,'shared_movie_time');
        fs_plane = getappdata(fig,'fs_plane');
        fs_motion = getappdata(fig,'fs_motion');
        plane = getappdata(fig,'plane');

        if ~isempty(t) && isscalar(t) && isfinite(t) && ...
                isscalar(fs_plane) && isfinite(fs_plane) && fs_plane>0 && ...
                isscalar(fs_motion) && isfinite(fs_motion) && fs_motion>0 && ...
                isscalar(plane) && isfinite(plane)
            frame_idx = round((t-(plane-1)/fs_motion)*fs_plane)+1;
        end

        if ~isempty(frame_idx) && isscalar(frame_idx) && ...
                isfinite(frame_idx)
            frame_idx = max(1,min(movie_data.nFrames,round(frame_idx)));
            title_text = sprintf('Cellule %d | frame %d / %d', ...
                round(cid),frame_idx,movie_data.nFrames);
        end
    end

    title(ax,title_text,'Interpreter','none');
end

function update_roi_zoom(fig)

    if ~isappdata(fig,'axROI')
        return;
    end

    ax = ...
        getappdata( ...
            fig, ...
            'axROI');

    if isempty(ax) || ...
            ~ishghandle(ax)

        return;
    end

    % Le crop est recalcule pour chaque cellule.
    setappdata(fig,'roi_crop_bounds',[]);

    %==============================================================
    % IMAGE MOYENNE
    %==============================================================

    meanImg = [];

    if isappdata(fig,'meanImg')

        meanImg = ...
            getappdata( ...
                fig, ...
                'meanImg');
    end

    if isempty(meanImg) || ...
            ~(isnumeric(meanImg) || islogical(meanImg))

        cla(ax);

        title( ...
            ax, ...
            'ROI indisponible');

        return;
    end

    meanImg = ...
        double(meanImg);

    %==============================================================
    % CELLULE COURANTE
    %==============================================================

    if ~isappdata(fig,'cell_id')

        cla(ax);

        imagesc( ...
            ax, ...
            meanImg);

        colormap(ax,gray);

        axis(ax,'image');

        set( ...
            ax, ...
            'YDir', ...
            'reverse');

        title( ...
            ax, ...
            'ROI indisponible');

        return;
    end

    cid = ...
        round( ...
            getappdata( ...
                fig, ...
                'cell_id'));

    %==============================================================
    % PIXEL SIZE
    %==============================================================

    pixel_size_um = NaN;

    if isappdata(fig,'pixel_size_um')

        pixel_size_um = ...
            getappdata( ...
                fig, ...
                'pixel_size_um');
    end

    %==============================================================
    % MASQUE
    %
    % Utilisé uniquement pour définir automatiquement le crop.
    % Il n'est plus utilisé pour l'overlay.
    %==============================================================

    mask = [];

    if isappdata(fig,'masks')

        masks = ...
            getappdata( ...
                fig, ...
                'masks');

        if ~isempty(masks) && ...
                (isnumeric(masks) || islogical(masks)) && ...
                ndims(masks) >= 3 && ...
                cid >= 1 && ...
                cid <= size(masks,1)

            mask = ...
                squeeze( ...
                    masks(cid,:,:));
        end
    end

    %==============================================================
    % VRAIS OUTLINES
    %==============================================================

    outline_x = [];
    outline_y = [];

    if isappdata(fig,'outlines_x') && ...
            isappdata(fig,'outlines_y')

        outlines_x = ...
            getappdata( ...
                fig, ...
                'outlines_x');

        outlines_y = ...
            getappdata( ...
                fig, ...
                'outlines_y');

        if iscell(outlines_x) && ...
                iscell(outlines_y) && ...
                cid >= 1 && ...
                cid <= numel(outlines_x) && ...
                cid <= numel(outlines_y)

            outline_x = ...
                outlines_x{cid};

            outline_y = ...
                outlines_y{cid};
        end
    end

    %==============================================================
    % SI MASQUE INDISPONIBLE
    %==============================================================

    if isempty(mask)

        cla(ax);

        imagesc( ...
            ax, ...
            meanImg);

        colormap(ax,gray);

        axis(ax,'image');

        set( ...
            ax, ...
            'YDir', ...
            'reverse');

        title( ...
            ax, ...
            sprintf( ...
                'Cellule %d (masque indisponible)', ...
                cid));

        add_scale_bar( ...
            ax, ...
            pixel_size_um);

        return;
    end

    mask = ...
        logical(mask);

    if ~ismatrix(mask) || ...
            ~any(mask(:))

        cla(ax);

        imagesc( ...
            ax, ...
            meanImg);

        colormap(ax,gray);

        axis(ax,'image');

        set( ...
            ax, ...
            'YDir', ...
            'reverse');

        title( ...
            ax, ...
            sprintf( ...
                'Cellule %d (masque vide)', ...
                cid));

        add_scale_bar( ...
            ax, ...
            pixel_size_um);

        return;
    end

    %==============================================================
    % VÉRIFICATION DIMENSIONS
    %==============================================================

    [Himg,Wimg] = ...
        size(meanImg);

    [Hm,Wm] = ...
        size(mask);

    if Himg ~= Hm || ...
            Wimg ~= Wm

        cla(ax);

        imagesc( ...
            ax, ...
            meanImg);

        colormap(ax,gray);

        axis(ax,'image');

        set( ...
            ax, ...
            'YDir', ...
            'reverse');

        title( ...
            ax, ...
            sprintf( ...
                'Cellule %d (taille masque/image incompatible)', ...
                cid));

        add_scale_bar( ...
            ax, ...
            pixel_size_um);

        return;
    end

    %==============================================================
    % BOUNDING BOX AUTO
    %==============================================================

    [y,x] = ...
        find(mask);

    pad = 12;

    xmin = ...
        max( ...
            1, ...
            floor(min(x)) - pad);

    xmax = ...
        min( ...
            size(meanImg,2), ...
            ceil(max(x)) + pad);

    ymin = ...
        max( ...
            1, ...
            floor(min(y)) - pad);

    ymax = ...
        min( ...
            size(meanImg,1), ...
            ceil(max(y)) + pad);

    %==============================================================
    % CROP UTILISE AUSSI PAR LE FILM
    %==============================================================

    setappdata( ...
        fig, ...
        'roi_crop_bounds', ...
        [xmin xmax ymin ymax]);

    cropImg = ...
        meanImg( ...
            ymin:ymax, ...
            xmin:xmax);

    %==============================================================
    % CONTRASTE AUTO
    %==============================================================

    v = ...
        cropImg( ...
            isfinite(cropImg));

    if isempty(v)

        lo = ...
            min( ...
                cropImg(:));

        hi = ...
            max( ...
                cropImg(:));

    else

        lo = ...
            prctile( ...
                v, ...
                5);

        hi = ...
            prctile( ...
                v, ...
                99.5);

        if ~isfinite(lo) || ...
                ~isfinite(hi) || ...
                hi <= lo

            lo = ...
                min(v);

            hi = ...
                max(v);
        end
    end

    %==============================================================
    % AFFICHAGE IMAGE
    %==============================================================

    cla(ax);

    imagesc( ...
        ax, ...
        cropImg);

    colormap(ax,gray);

    axis(ax,'image');

    set( ...
        ax, ...
        'YDir', ...
        'reverse');

    clim( ...
        ax, ...
        [lo hi]);

    hold(ax,'on');

    %==============================================================
    % VRAI OUTLINE
    %
    % On considère ici que outlines_x / outlines_y sont déjà
    % exprimés en coordonnées MATLAB 1-based.
    %==============================================================

    if ~isempty(outline_x) && ...
            ~isempty(outline_y)

        outline_x = ...
            double( ...
                outline_x(:));

        outline_y = ...
            double( ...
                outline_y(:));

        n = ...
            min( ...
                numel(outline_x), ...
                numel(outline_y));

        outline_x = ...
            outline_x(1:n);

        outline_y = ...
            outline_y(1:n);

        good = ...
            isfinite(outline_x) & ...
            isfinite(outline_y);

        outline_x = ...
            outline_x(good);

        outline_y = ...
            outline_y(good);

        if ~isempty(outline_x)

            %------------------------------------------------------
            % Coordonnées image globale -> coordonnées du crop
            %------------------------------------------------------

            outline_x_crop = ...
                outline_x - xmin + 1;

            outline_y_crop = ...
                outline_y - ymin + 1;

            plot( ...
                ax, ...
                outline_x_crop, ...
                outline_y_crop, ...
                'r-', ...
                'LineWidth', ...
                1.5);
        end
    end

    %==============================================================
    % SCALE BAR
    %==============================================================

    add_scale_bar( ...
        ax, ...
        pixel_size_um);

    %==============================================================
    % TITRE
    %==============================================================

    iscell_label = '';

    if isappdata(fig,'iscell_idx_display')

        iscell_idx_display = ...
            getappdata( ...
                fig, ...
                'iscell_idx_display');

        if ~isempty(iscell_idx_display) && ...
                cid >= 1 && ...
                cid <= numel(iscell_idx_display) && ...
                isfinite(iscell_idx_display(cid))

            iscell_label = ...
                sprintf( ...
                    ' | iscell idx %d', ...
                    round( ...
                        iscell_idx_display(cid) - 1));
        end
    end

    title( ...
        ax, ...
        sprintf( ...
            'Cellule %d%s', ...
            cid, ...
            iscell_label), ...
        'Interpreter', ...
        'none');

    hold(ax,'off');
end

function add_scale_bar(ax, pixel_size_um)

    if isempty(ax) || ~ishghandle(ax) || ~isfinite(pixel_size_um) || pixel_size_um <= 0
        return;
    end

    xl = xlim(ax);
    yl = ylim(ax);

    w = abs(diff(xl));
    h = abs(diff(yl));

    if w <= 0 || h <= 0
        return;
    end

    candidate_um = [5 10 20 25 50 100];
    target_um = 0.25 * w * pixel_size_um;
    [~, idx] = min(abs(candidate_um - target_um));
    bar_um = candidate_um(idx);

    bar_px = bar_um / pixel_size_um;

    x0 = xl(1) + 0.08 * w;
    x1 = x0 + bar_px;

    y0 = yl(1) + 0.92 * h;

    plot(ax, [x0 x1], [y0 y0], 'k-', 'LineWidth', 5, 'Clipping', 'off');
    plot(ax, [x0 x1], [y0 y0], 'w-', 'LineWidth', 3, 'Clipping', 'off');

    text(ax, (x0+x1)/2, y0 - 0.04*h, sprintf('%g \\mum', bar_um), ...
        'Color','w', 'FontWeight','bold', 'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', 'Clipping','off', ...
        'BackgroundColor','k', 'Margin',1);
end

%% ===================== GUI PARAMETERS =====================

function make_slider(parent,fig,label,field,minv,maxv,val,pos)

    intFields = {'savgol_win_ms','window_size_s','refrac_ms'};

    if ismember(field,intFields)
        val = round(max(minv, min(maxv, val)));
        fmt = '%s = %d';
    else
        val = max(minv, min(maxv, val));
        fmt = '%s = %.2f';
    end

    uicontrol('Parent',parent,'Style','text', ...
        'String',sprintf(fmt,label,val), ...
        'Units','normalized', ...
        'Position',[pos(1) pos(2)+0.05 pos(3) 0.04], ...
        'Tag',['lbl_' field], ...
        'HorizontalAlignment','left', ...
        'FontWeight','normal');

    uicontrol('Parent',parent,'Style','slider', ...
        'Min',minv, ...
        'Max',maxv, ...
        'Value',val, ...
        'Units','normalized', ...
        'Position',pos, ...
        'Tag',['sldr_' field], ...
        'Callback',@(src,~) update_param(fig,field,get(src,'Value')));
end

function reset_detection_params(fig)

    if isempty(fig) || ...
            ~ishghandle(fig) || ...
            ~isappdata(fig,'opts')

        return;
    end

    %==============================================================
    % VALEURS PAR DEFAUT
    %==============================================================

    default_values = ...
        struct( ...
            'window_size_s',       120, ...
            'prominence_factor',     1, ...
            'refrac_ms',           300, ...
            'savgol_win_ms',       300);

    fields = ...
        fieldnames(default_values);

    opts = ...
        getappdata( ...
            fig, ...
            'opts');

    changed_fields = ...
        {};

    %==============================================================
    % REPLACER LES SLIDERS ET IDENTIFIER LES VRAIS CHANGEMENTS
    %==============================================================

    for k = 1:numel(fields)

        field = ...
            fields{k};

        default_value = ...
            default_values.(field);

        hSlider = ...
            findobj( ...
                fig, ...
                'Tag', ...
                ['sldr_' field]);

        if ~isempty(hSlider) && ...
                isgraphics(hSlider)

            set( ...
                hSlider, ...
                'Value', ...
                default_value);
        end

        current_value = ...
            NaN;

        if isfield(opts,field) && ...
                ~isempty(opts.(field))

            current_value = ...
                double(opts.(field));
        end

        if ~isfinite(current_value) || ...
                abs(current_value - default_value) > eps(max(1,abs(default_value)))

            changed_fields{end+1} = ...
                field; %#ok<AGROW>
        end
    end

    %==============================================================
    % RIEN A CHANGER
    %==============================================================

    if isempty(changed_fields)

        return;
    end

    %==============================================================
    % APPLIQUER LES VALEURS PAR DEFAUT
    %
    % update_param garde exactement la meme logique que lorsqu'un
    % curseur est deplace manuellement :
    %   - mise a jour opts
    %   - recalcul interactif de la cellule courante
    %   - en Viewer : selection_modified = true
    %   - bouton Confirmer selection debloque
    %==============================================================

    for k = 1:numel(changed_fields)

        field = ...
            changed_fields{k};

        update_param( ...
            fig, ...
            field, ...
            default_values.(field));
    end
end

function update_param(fig, field, value)

    viewer_mode = ...
        isappdata(fig,'viewer_mode') && ...
        getappdata(fig,'viewer_mode');

    opts = ...
        getappdata(fig,'opts');

    fs_plane = ...
        getappdata(fig,'fs_plane');

    intFields = { ...
        'savgol_win_ms', ...
        'window_size_s', ...
        'refrac_ms'};

    if ismember(field,intFields)

        value = ...
            round(value);

        value = ...
            max(0,value);

    else

        value = ...
            max(0,value);
    end

    %==============================================================
    % METTRE A JOUR LES OPTIONS
    %==============================================================

    opts.(field) = ...
        value;

    opts = ...
        convert_opts_ms_to_frames( ...
            opts, ...
            fs_plane);

    setappdata( ...
        fig, ...
        'opts', ...
        opts);

    % Seuls ces parametres changent le DF utilise par raster_processing.
    % La suppression / reintegration d'une cellule ne pose PAS ce flag.
    if ismember(field,{'window_size_s','savgol_win_ms'})
        setappdata(fig,'peak_sort_df_changed',true);
    end

    %==============================================================
    % LABEL DU SLIDER
    %==============================================================

    lbl = ...
        findobj( ...
            fig, ...
            'Tag', ...
            ['lbl_' field]);

    if ~isempty(lbl)

        eqPos = ...
            strfind( ...
                lbl.String, ...
                '=');

        if ~isempty(eqPos)

            base = ...
                strtrim( ...
                    lbl.String(1:eqPos(1)-1));

        else

            base = ...
                field;
        end

        if strcmp(field,'savgol_win_ms')

            lbl.String = ...
                sprintf( ...
                    '%s = %d ms (%d frames)', ...
                    base, ...
                    value, ...
                    opts.savgol_win);

        elseif ismember(field,intFields)

            lbl.String = ...
                sprintf( ...
                    '%s = %d', ...
                    base, ...
                    value);

        else

            lbl.String = ...
                sprintf( ...
                    '%s = %.2f', ...
                    base, ...
                    value);
        end
    end

    %==============================================================
    % VIEWER : UN CHANGEMENT DE PARAMETRE EST UNE MODIFICATION
    %
    % - débloque Confirmer sélection
    % - aucune sauvegarde tant que l'utilisateur ne confirme pas
    % - à la confirmation : recalcul complet du plan
    %==============================================================

    if viewer_mode

        setappdata( ...
            fig, ...
            'detection_params_modified', ...
            true);

        setappdata( ...
            fig, ...
            'selection_modified', ...
            true);

        changed_fields = {};

        if isappdata(fig,'viewer_changed_param_fields')

            changed_fields = ...
                getappdata( ...
                    fig, ...
                    'viewer_changed_param_fields');
        end

        if isempty(changed_fields)
            changed_fields = {};
        end

        if ~ismember(field,changed_fields)
            changed_fields{end+1} = field;
        end

        setappdata( ...
            fig, ...
            'viewer_changed_param_fields', ...
            changed_fields);

        update_population_action_buttons(fig);
    end

    %==============================================================
    % CELLULE COURANTE
    %==============================================================

    if ~isappdata(fig,'cell_id')
        return;
    end

    cid = ...
        getappdata( ...
            fig, ...
            'cell_id');

    if isempty(cid) || ...
            ~isscalar(cid) || ...
            ~isfinite(cid)

        return;
    end

    cid = ...
        round(cid);

    DF_sg = ...
        getappdata( ...
            fig, ...
            'DF_sg');

    if cid < 1 || ...
            cid > size(DF_sg,1)

        return;
    end

    if isappdata(fig,'bad_frames')

        bad_frames = ...
            getappdata( ...
                fig, ...
                'bad_frames');

    else

        bad_frames = [];
    end

    %==============================================================
    % WINDOW / SAVGOL
    %
    % Recalcul immédiat uniquement de la cellule courante pour
    % l'affichage interactif.
    % Le plan entier sera recalculé seulement à la confirmation.
    %==============================================================

    if ismember( ...
            field, ...
            {'window_size_s','savgol_win_ms'})

        F = ...
            getappdata( ...
                fig, ...
                'F_raw');

        if isempty(F) || ...
                cid > size(F,1)

            return;
        end

        F_cell = ...
            F(cid,:);

        [ ...
            DF_raw_cell, ...
            F0_cell ...
        ] = ...
            F_processing( ...
                F_cell, ...
                bad_frames, ...
                fs_plane, ...
                opts.window_size);

        DF_sg_cell = ...
            savgol_transform( ...
                DF_raw_cell, ...
                opts);

        noise_cell = ...
            estimate_noise( ...
                DF_raw_cell);

        DF_raw = ...
            getappdata( ...
                fig, ...
                'DF_raw');

        DF_sg = ...
            getappdata( ...
                fig, ...
                'DF_sg');

        F0 = ...
            getappdata( ...
                fig, ...
                'F0');

        noise_est = ...
            getappdata( ...
                fig, ...
                'noise_est');

        if isempty(DF_raw) || ...
                size(DF_raw,1) ~= size(F,1)

            DF_raw = ...
                nan(size(F));
        end

        if isempty(DF_sg) || ...
                size(DF_sg,1) ~= size(F,1)

            DF_sg = ...
                nan(size(F));
        end

        if isempty(F0) || ...
                size(F0,1) ~= size(F,1)

            F0 = ...
                nan(size(F));
        end

        if isempty(noise_est) || ...
                numel(noise_est) ~= size(F,1)

            noise_est = ...
                nan(size(F,1),1);

        else

            noise_est = ...
                noise_est(:);
        end

        DF_raw(cid,:) = ...
            DF_raw_cell;

        DF_sg(cid,:) = ...
            DF_sg_cell;

        F0(cid,:) = ...
            F0_cell;

        noise_est(cid,1) = ...
            noise_cell;

        setappdata(fig,'DF_raw',DF_raw);
        setappdata(fig,'DF_sg',DF_sg);
        setappdata(fig,'F0',F0);
        setappdata(fig,'noise_est',noise_est);
    end

    %==============================================================
    % TOUS LES PARAMETRES
    %
    % Recalcul immédiat des pics de la cellule courante.
    %==============================================================

    setappdata(fig,'autotervals',[]);
    setappdata(fig,'auto_peaks',[]);

    if isappdata(fig,'seuil_detection_last')
        rmappdata(fig,'seuil_detection_last');
    end

    auto_detect_and_add(fig);

    %==============================================================
    % Nombre de pics de la cellule courante
    %==============================================================

    if isappdata(fig,'auto_peaks') && ...
            isappdata(fig,'n_peaks_all')

        auto_peaks = ...
            getappdata( ...
                fig, ...
                'auto_peaks');

        n_peaks_all = ...
            getappdata( ...
                fig, ...
                'n_peaks_all');

        if cid >= 1 && ...
                cid <= numel(n_peaks_all)

            n_peaks_all(cid) = ...
                numel(auto_peaks);

            setappdata( ...
                fig, ...
                'n_peaks_all', ...
                n_peaks_all);
        end
    end

    refresh_data(fig);
    update_peak_raster_title(fig);
    drawnow;
end


function recompute_viewer_detection_all(fig)

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    %==============================================================
    % INPUTS
    %==============================================================

    F = ...
        getappdata( ...
            fig, ...
            'F_raw');

    opts = ...
        getappdata( ...
            fig, ...
            'opts');

    fs_plane = ...
        getappdata( ...
            fig, ...
            'fs_plane');

    if isappdata(fig,'bad_frames')

        bad_frames = ...
            getappdata( ...
                fig, ...
                'bad_frames');

    else

        bad_frames = [];
    end

    if isempty(F)
        return;
    end

    %==============================================================
    % PREPROCESSING COMPLET DU PLAN
    %==============================================================

    [ ...
        DF_raw_all, ...
        F0_all ...
    ] = ...
        F_processing( ...
            F, ...
            bad_frames, ...
            fs_plane, ...
            opts.window_size);

    DF_sg_all = ...
        savgol_transform( ...
            DF_raw_all, ...
            opts);

    noise_est_all = ...
        estimate_noise( ...
            DF_raw_all);

    %==============================================================
    % QUALITY
    %==============================================================

    [ ...
        ~, ...
        SNR, ...
        score, ...
        cells_sorted_by_quality, ...
        ~, ...
        ~, ...
        ~ ...
    ] = ...
        compute_snr_quality( ...
            DF_sg_all, ...
            noise_est_all, ...
            opts, ...
            bad_frames);

    score_quality_percentile = ...
        nan(size(score));

    valid_score = ...
        isfinite(score);

    [~,order_score] = ...
        sort( ...
            score(valid_score), ...
            'ascend');

    tmp = ...
        nan( ...
            sum(valid_score), ...
            1);

    if ~isempty(tmp)

        tmp(order_score) = ...
            linspace( ...
                0, ...
                100, ...
                sum(valid_score));
    end

    score_quality_percentile(valid_score) = ...
        tmp;

    %==============================================================
    % PEAKS COMPLETS
    %==============================================================

    nCells = ...
        size(DF_sg_all,1);

    nFrames = ...
        size(DF_sg_all,2);

    Raster_all = ...
        false( ...
            nCells, ...
            nFrames);

    Acttmp2_all = ...
        cell(nCells,1);

    thresholds_all = ...
        nan(nCells,1);

    n_peaks_all = ...
        zeros(nCells,1);

    for cid = 1:nCells

        x = ...
            DF_sg_all(cid,:).';

        sigma = ...
            noise_est_all(cid);

        if ~isfinite(sigma) || ...
                sigma <= 0

            sigma = ...
                std( ...
                    x, ...
                    'omitnan');
        end

        if ~isfinite(sigma) || ...
                sigma <= 0

            sigma = eps;
        end

        out = ...
            detect_peaks_cell_core( ...
                x, ...
                sigma, ...
                opts, ...
                bad_frames);

        Acttmp2_all{cid} = ...
            out.locs_raw;

        thresholds_all(cid) = ...
            out.threshold;

        n_peaks_all(cid) = ...
            numel(out.locs_raw);

        if ~isempty(out.locs_raw)

            Raster_all( ...
                cid, ...
                out.locs_raw) = ...
                true;
        end
    end

    %==============================================================
    % APPDATA
    %==============================================================

    setappdata(fig,'DF_raw',DF_raw_all);
    setappdata(fig,'DF_sg',DF_sg_all);
    setappdata(fig,'F0',F0_all);
    setappdata(fig,'noise_est',noise_est_all);

    setappdata(fig,'SNR',SNR);
    setappdata(fig,'score_quality',score);
    setappdata(fig,'cells_sorted_by_quality',cells_sorted_by_quality);
    setappdata(fig,'score_quality_percentile',score_quality_percentile);

    setappdata(fig,'Raster_saved',Raster_all);
    setappdata(fig,'Acttmp2_saved',Acttmp2_all);
    setappdata(fig,'thresholds_saved',thresholds_all);
    setappdata(fig,'n_peaks_all',n_peaks_all);
end

%% ===================== FILMS INTEGRES AU VIEWER =====================

function restore_embedded_mean_image(fig)
    % Au repos, l'image moyenne et son contour redeviennent visibles
    % au-dessus du film comportemental. Aucun temps n'est modifie.
    if isempty(fig) || ~ishghandle(fig)
        return;
    end
    setappdata(fig,'roi_movie_visible',false);
    setappdata(fig,'roi_movie_hImg',[]);
    if getappdata(fig,'viewer_mode')
        update_viewer_roi_zoom(fig);
    else
        update_roi_zoom(fig);
    end
end

%% ===================== COMMANDE VIDEO UNIQUE =====================

function navigate_speed_active(fig,direction)
    % Naviguer entre les DEBUTS des episodes binaires speed_active.
    % Tous les temps sont globaux, comme la camera et motion_energy.
    % Aucune action sur les donnees de detection ou sur la selection.
    if isempty(fig) || ~ishghandle(fig) || ...
            ~ismember(direction,[-1 1])
        return;
    end

    onset_times = getappdata(fig,'speed_active_onset_times');
    end_times = getappdata(fig,'speed_active_end_times');
    if isempty(onset_times) || numel(onset_times) ~= numel(end_times)
        return;
    end

    % Arreter le seul timer actif avant le saut.
    pause_roi_movie(fig);
    pause_behavior_movie(fig);
    restore_embedded_mean_image(fig);
    setappdata(fig,'speed_active_stop_time',[]);

    % Determiner les bornes communes REELLES des films disponibles.
    % Cette operation indexe les TIFF au plus une fois (cache existant).
    current_time = getappdata(fig,'shared_movie_time');
    if isempty(current_time) || ~isscalar(current_time) || ...
            ~isfinite(current_time)
        current_time = 0;
    end

    seek_shared_movie_time(fig,current_time);
    current_time = getappdata(fig,'shared_movie_time');
    max_time = getappdata(fig,'shared_movie_max_time');

    min_time = 0;
    roi_data = getappdata(fig,'roi_movie_data');
    crop = getappdata(fig,'roi_crop_bounds');
    if ~isempty(roi_data) && ~isempty(crop) && numel(crop)==4
        min_time = (getappdata(fig,'plane')-1) / ...
            getappdata(fig,'fs_motion');
    end

    if isempty(max_time) || ~isscalar(max_time) || isnan(max_time)
        max_time = Inf;
    end

    % Exclure les debuts hors de l'intervalle commun : sinon, seek()
    % les ramenerait a une borne sans parvenir a l'episode demande.
    fs_motion = getappdata(fig,'fs_motion');
    valid_episodes = ...
        onset_times >= min_time-1e-9 & ...
        onset_times <= max_time+1e-9;
    onset_times = onset_times(valid_episodes);
    end_times = end_times(valid_episodes);

    % Comparaison stricte, avec une petite tolerance numerique :
    % un deuxieme clic avance meme si le curseur est sur le debut exact.
    tolerance = min(1e-6,1e-3/fs_motion);
    if direction < 0
        % Depuis la fin d'un episode, la fleche gauche doit aller
        % au PRECEDENT episode, sans relancer celui qui vient de finir.
        last_onset = getappdata(fig,'speed_active_last_onset_time');
        if ~isempty(last_onset) && isscalar(last_onset) && ...
                isfinite(last_onset) && ...
                any(abs(end_times-current_time) <= tolerance & ...
                    abs(onset_times-last_onset) <= tolerance)
            current_time = last_onset;
        end
        idx = find(onset_times < current_time-tolerance,1,'last');
    else
        idx = find(onset_times > current_time+tolerance,1,'first');
    end

    if isempty(idx)
        return;
    end

    % Les fleches ne lancent pas de film et gardent l'image moyenne.
    seek_shared_movie_time(fig,onset_times(idx));
    stop_time = min(end_times(idx),max_time);
    setappdata(fig,'speed_active_last_onset_time',onset_times(idx));
    setappdata(fig,'speed_active_stop_time',stop_time);
end

function toggle_shared_movie(fig)

    if isempty(fig) || ~ishghandle(fig)
        return;
    end

    roi_playing = ...
        isappdata(fig,'roi_movie_playing') && ...
        getappdata(fig,'roi_movie_playing');

    behavior_playing = ...
        isappdata(fig,'behavior_movie_playing') && ...
        getappdata(fig,'behavior_movie_playing');

    if roi_playing || behavior_playing
        % Pause manuelle : garder l'episode selectionne. Une reprise
        % continuera jusqu'a sa fin, sans passer a l'episode suivant.
        pause_roi_movie(fig);
        pause_behavior_movie(fig);
        restore_embedded_mean_image(fig);
        return;
    end

    % Apres navigation par fleche, le bouton Play doit respecter la
    % fin de CET episode. Pour un episode d'une seule frame, ne pas
    % demarrer un timer qui avancerait immediatement au-dela.
    stop_time = getappdata(fig,'speed_active_stop_time');
    if ~isempty(stop_time) && isscalar(stop_time) && ...
            isfinite(stop_time)
        current_time = getappdata(fig,'shared_movie_time');
        if ~isempty(current_time) && isscalar(current_time) && ...
                isfinite(current_time) && current_time >= stop_time-1e-9
            seek_shared_movie_time(fig,stop_time);
            setappdata(fig,'speed_active_stop_time',[]);
            update_shared_movie_button(fig);
            return;
        end
    end

    % La camera est l'horloge maitresse si elle est disponible.
    % seek_shared_movie_time() aligne chaque frame ROI sur son temps global.
    camera_data = getappdata(fig,'behavior_movie_data');
    camera_path = getappdata(fig,'behavior_movie_path');

    if isempty(camera_data) && ~isempty(camera_path) && isfile(camera_path)
        camera_data = get_behavior_movie_data(fig);
    end

    % Afficher le film ROI a la place de l'image moyenne uniquement
    % durant la lecture. Sans reg_tif, conserver l'image moyenne.
    roi_path = getappdata(fig,'suite2p_path');
    crop = getappdata(fig,'roi_crop_bounds');
    roi_available = ~isempty(roi_path) && ~isempty(crop) && ...
        isfolder(fullfile(char(string(roi_path)),'reg_tif'));
    setappdata(fig,'roi_movie_visible',roi_available);
    if ~isempty(camera_data) && ...
            isfield(camera_data,'nFrames') && ...
            camera_data.nFrames > 1
        toggle_behavior_movie(fig);
    else
        % Le film ROI reste utilisable si la camera est absente.
        toggle_roi_movie(fig);
    end
end


function reached = stop_at_speed_active_end(fig,t_next)
    % Le timer peut sauter plusieurs frames en cas de lecture disque lente.
    % Toujours afficher la DERNIERE frame active, puis arreter les films.
    reached = false;
    stop_time = getappdata(fig,'speed_active_stop_time');
    if isempty(stop_time) || ~isscalar(stop_time) || ...
            ~isfinite(stop_time) || t_next < stop_time - 1e-9
        return;
    end

    seek_shared_movie_time(fig,stop_time);
    pause_roi_movie(fig);
    pause_behavior_movie(fig);
    restore_embedded_mean_image(fig);
    setappdata(fig,'speed_active_stop_time',[]);
    reached = true;
end


function update_shared_movie_button(fig)

    if isempty(fig) || ~ishghandle(fig)
        return;
    end

    btn = findobj(fig,'Tag','btn_shared_movie');
    if isempty(btn) || ~ishghandle(btn)
        return;
    end

    playing = ...
        (isappdata(fig,'roi_movie_playing') && ...
         getappdata(fig,'roi_movie_playing')) || ...
        (isappdata(fig,'behavior_movie_playing') && ...
         getappdata(fig,'behavior_movie_playing'));

    if playing
        set(btn,'String','⏸');
    else
        set(btn,'String','▶');
    end
end


%% ===================== ROI MOVIE =====================

function toggle_roi_movie(fig)

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    playing = false;

    if isappdata(fig,'roi_movie_playing')

        playing = ...
            logical( ...
                getappdata( ...
                    fig, ...
                    'roi_movie_playing'));
    end

    %==============================================================
    % PAUSE
    %==============================================================

    if playing

        pause_roi_movie(fig);
        return;
    end

    %==============================================================
    % CROP DE LA CELLULE COURANTE
    %==============================================================

    if ~isappdata(fig,'roi_crop_bounds')
        return;
    end

    crop_bounds = ...
        getappdata( ...
            fig, ...
            'roi_crop_bounds');

    if isempty(crop_bounds) || ...
            numel(crop_bounds) ~= 4

        fprintf( ...
            'ROI movie: aucun crop disponible pour cette cellule.\n');

        return;
    end

    %==============================================================
    % INDEXER LES REG_TIF
    %==============================================================

    movie_data = ...
        get_roi_movie_data(fig);

    if isempty(movie_data)

        fprintf( ...
            'ROI movie: aucun reg_tif disponible.\n');

        return;
    end

    %==============================================================
    %==============================================================
    % Reprendre au temps global commun (avec offset du plan).
    fs_plane = getappdata(fig,'fs_plane');
    fs_motion = getappdata(fig,'fs_motion');
    plane = getappdata(fig,'plane');
    t_start = getappdata(fig,'shared_movie_time');
    if isempty(t_start) || ~isfinite(t_start)
        t_start = (plane-1)/fs_motion;
    end

    pause_behavior_movie(fig); % un seul timer maitre a la fois
    seek_shared_movie_time(fig,t_start);

    % La recherche temporelle peut avoir recale les frames aux bornes.
    frame_idx = getappdata(fig,'roi_movie_frame');
    if frame_idx >= movie_data.nFrames
        seek_shared_movie_time(fig,(plane-1)/fs_motion);
        frame_idx = getappdata(fig,'roi_movie_frame');
    end

    %==============================================================
    % VITESSE REELLE DU PLAN
    %==============================================================

    fs_plane = ...
        getappdata( ...
            fig, ...
            'fs_plane');

    if isempty(fs_plane) || ...
            ~isfinite(fs_plane) || ...
            fs_plane <= 0

        fs_plane = 10;
    end

    period_sec = ...
        max( ...
            0.02, ...
            1 / fs_plane);

    %==============================================================
    % SUPPRIMER UN ANCIEN TIMER
    %==============================================================

    old_timer = [];

    if isappdata(fig,'roi_movie_timer')

        old_timer = ...
            getappdata( ...
                fig, ...
                'roi_movie_timer');
    end

    if ~isempty(old_timer)

        try
            stop(old_timer);
        catch
        end

        try
            delete(old_timer);
        catch
        end
    end

    %==============================================================
    % TIMER DE LECTURE
    %==============================================================

    movie_timer = ...
        timer( ...
            'ExecutionMode', ...
            'fixedRate', ...
            'Period', ...
            period_sec, ...
            'BusyMode', ...
            'drop', ...
            'TimerFcn', ...
            @(~,~) advance_roi_movie(fig));

    setappdata( ...
        fig, ...
        'roi_movie_timer', ...
        movie_timer);

    setappdata( ...
        fig, ...
        'roi_movie_playing', ...
        true);

    update_shared_movie_button(fig);

    try
        start(movie_timer);
    catch ME
        setappdata(fig,'roi_movie_playing',false);
        update_shared_movie_button(fig);
        warning('peak_detection_tuner:RoiTimerStartFailed', ...
            'Impossible de demarrer le film ROI : %s',ME.message);
    end
end


function advance_roi_movie(fig)

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    if ~isappdata(fig,'roi_movie_playing') || ...
            ~getappdata(fig,'roi_movie_playing')

        return;
    end

    movie_data = [];

    if isappdata(fig,'roi_movie_data')

        movie_data = ...
            getappdata( ...
                fig, ...
                'roi_movie_data');
    end

    if isempty(movie_data) || ...
            ~isstruct(movie_data) || ...
            ~isfield(movie_data,'nFrames')

        pause_roi_movie(fig);
        restore_embedded_mean_image(fig);
        return;
    end

    frame_idx = 1;

    if isappdata(fig,'roi_movie_frame')

        frame_idx = ...
            getappdata( ...
                fig, ...
                'roi_movie_frame');
    end

    if isempty(frame_idx) || ...
            ~isfinite(frame_idx)

        frame_idx = 1;
    end

    frame_idx = ...
        round(frame_idx) + 1;

    fs_plane = getappdata(fig,'fs_plane');
    fs_motion = getappdata(fig,'fs_motion');
    plane = getappdata(fig,'plane');
    t_next = (plane-1)/fs_motion + (frame_idx-1)/fs_plane;

    if stop_at_speed_active_end(fig,t_next)
        return;
    end

    %==============================================================
    % FIN DE L'ENREGISTREMENT
    %==============================================================

    if frame_idx > movie_data.nFrames

        setappdata( ...
            fig, ...
            'roi_movie_frame', ...
            movie_data.nFrames);

        pause_roi_movie(fig);
        restore_embedded_mean_image(fig);
        return;
    end

    t_max = getappdata(fig,'shared_movie_max_time');
    if ~isempty(t_max) && t_next > t_max + 1e-9
        pause_roi_movie(fig);
        restore_embedded_mean_image(fig);
        return;
    end
    seek_shared_movie_time(fig,t_next);
end


function pause_roi_movie(fig)

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    movie_timer = [];

    if isappdata(fig,'roi_movie_timer')

        movie_timer = ...
            getappdata( ...
                fig, ...
                'roi_movie_timer');
    end

    if ~isempty(movie_timer)

        try
            stop(movie_timer);
        catch
        end
    end

    setappdata( ...
        fig, ...
        'roi_movie_playing', ...
        false);

    update_shared_movie_button(fig);
end


function reset_roi_movie_display(fig)

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    movie_timer = [];

    if isappdata(fig,'roi_movie_timer')

        movie_timer = ...
            getappdata( ...
                fig, ...
                'roi_movie_timer');
    end

    if ~isempty(movie_timer)

        try
            stop(movie_timer);
        catch
        end

        try
            delete(movie_timer);
        catch
        end
    end

    setappdata(fig,'roi_movie_timer',[]);
    setappdata(fig,'roi_movie_playing',false);
    setappdata(fig,'roi_movie_frame',1);
    setappdata(fig,'roi_movie_hImg',[]);
    setappdata(fig,'roi_movie_clim',[]);
    setappdata(fig,'roi_crop_bounds',[]);

    %==============================================================
    % Le curseur partage reste visible pendant la navigation cellulaire.
    % La camera conserve son temps et son image.
    %==============================================================

    % roi_movie_data n'est volontairement PAS supprime :
    % les fichiers TIFF et imfinfo sont les memes pour toutes les
    % cellules du plan et ne doivent pas etre reindexes a chaque cellule.

    update_shared_movie_button(fig);
end


function movie_data = get_roi_movie_data(fig)

    movie_data = [];

    %==============================================================
    % DEJA INDEXE POUR CE PLAN
    %==============================================================

    if isappdata(fig,'roi_movie_data')

        movie_data_saved = ...
            getappdata( ...
                fig, ...
                'roi_movie_data');

        if ~isempty(movie_data_saved) && ...
                isstruct(movie_data_saved) && ...
                isfield(movie_data_saved,'nFrames') && ...
                movie_data_saved.nFrames > 0

            movie_data = ...
                movie_data_saved;

            return;
        end
    end

    %==============================================================
    % TROUVER LE DOSSIER REG_TIF
    %==============================================================

    reg_tif_dir = ...
        find_roi_reg_tif_folder(fig);

    if isempty(reg_tif_dir)
        return;
    end

    files = ...
        dir( ...
            fullfile( ...
                reg_tif_dir, ...
                '*.tif'));

    if isempty(files)

        fprintf( ...
            'ROI movie: aucun TIFF dans %s\n', ...
            reg_tif_dir);

        return;
    end

    %==============================================================
    % TRI file000.tif, file001.tif, ...
    %==============================================================

    numbers = ...
        nan( ...
            numel(files), ...
            1);

    for k = 1:numel(files)

        tok = ...
            regexp( ...
                files(k).name, ...
                'file(\d+)', ...
                'tokens', ...
                'once');

        if isempty(tok)

            numbers(k) = Inf;

        else

            numbers(k) = ...
                str2double(tok{1});
        end
    end

    [~,ord] = ...
        sort(numbers);

    files = ...
        files(ord);

    fullPaths = ...
        fullfile( ...
            reg_tif_dir, ...
            {files.name});

    %==============================================================
    % NOMBRE DE PAGES PAR TIFF
    %==============================================================

    infos = ...
        cell( ...
            numel(fullPaths), ...
            1);

    pagesPerFile = ...
        zeros( ...
            numel(fullPaths), ...
            1);

    for k = 1:numel(fullPaths)

        infos{k} = ...
            imfinfo( ...
                fullPaths{k});

        pagesPerFile(k) = ...
            numel( ...
                infos{k});
    end

    cumulativePages = ...
        cumsum( ...
            pagesPerFile);

    if isempty(cumulativePages) || ...
            cumulativePages(end) < 1

        return;
    end

    movie_data = struct();

    movie_data.reg_tif_dir = ...
        reg_tif_dir;

    movie_data.fullPaths = ...
        fullPaths;

    movie_data.infos = ...
        infos;

    movie_data.pagesPerFile = ...
        pagesPerFile;

    movie_data.cumulativePages = ...
        cumulativePages;

    nFramesAvailable = ...
        cumulativePages(end);

    nFramesAnalysis = ...
        nFramesAvailable;

    if isappdata(fig,'total_frame_count')

        nFramesTmp = ...
            getappdata( ...
                fig, ...
                'total_frame_count');

        if ~isempty(nFramesTmp) && ...
                isfinite(nFramesTmp) && ...
                nFramesTmp >= 1

            nFramesAnalysis = ...
                round(nFramesTmp);
        end
    end

    movie_data.nFrames = ...
        min( ...
            nFramesAvailable, ...
            nFramesAnalysis);

    setappdata( ...
        fig, ...
        'roi_movie_data', ...
        movie_data);

    fprintf( ...
        'ROI movie: %d frames trouvees dans %d fichiers TIFF.\n', ...
        movie_data.nFrames, ...
        numel(fullPaths));
end


function reg_tif_dir = find_roi_reg_tif_folder(fig)

    reg_tif_dir = '';

    if ~isappdata(fig,'suite2p_path')
        return;
    end

    suite2p_path = ...
        getappdata(fig,'suite2p_path');

    suite2p_path = ...
        char(string(suite2p_path));

    reg_tif_dir = ...
        fullfile( ...
            suite2p_path, ...
            'reg_tif');

    if ~isfolder(reg_tif_dir)

        fprintf( ...
            'reg_tif introuvable :\n%s\n', ...
            reg_tif_dir);

        reg_tif_dir = '';
    end

end

function show_roi_movie_frame( ...
        fig, ...
        frame_index, ...
        initialize_display)

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    if ~isappdata(fig,'roi_movie_data')
        return;
    end

    movie_data = ...
        getappdata( ...
            fig, ...
            'roi_movie_data');

    if isempty(movie_data) || ...
            ~isstruct(movie_data)

        return;
    end

    if ~isappdata(fig,'roi_crop_bounds')
        return;
    end

    crop_bounds = ...
        getappdata( ...
            fig, ...
            'roi_crop_bounds');

    if isempty(crop_bounds) || ...
            numel(crop_bounds) ~= 4

        return;
    end

    xmin = crop_bounds(1);
    xmax = crop_bounds(2);
    ymin = crop_bounds(3);
    ymax = crop_bounds(4);

    %==============================================================
    % FRAME -> FICHIER TIFF + PAGE
    %==============================================================

    frame_index = ...
        max( ...
            1, ...
            min( ...
                round(frame_index), ...
                movie_data.nFrames));

    fileIdx = ...
        find( ...
            movie_data.cumulativePages >= ...
            frame_index, ...
            1, ...
            'first');

    if isempty(fileIdx)
        return;
    end

    if fileIdx == 1

        pageIdx = ...
            frame_index;

    else

        pageIdx = ...
            frame_index - ...
            movie_data.cumulativePages( ...
                fileIdx - 1);
    end

    %==============================================================
    % LIRE UNE SEULE FRAME
    %==============================================================

    try

        I = ...
            imread( ...
                movie_data.fullPaths{fileIdx}, ...
                pageIdx, ...
                'Info', ...
                movie_data.infos{fileIdx});

    catch ME

        warning( ...
            'ROI movie: impossible de lire frame %d : %s', ...
            frame_index, ...
            ME.message);

        return;
    end

    I = ...
        double(I);

    %==============================================================
    % SECURISER LE CROP
    %==============================================================

    xmin = ...
        max( ...
            1, ...
            round(xmin));

    xmax = ...
        min( ...
            size(I,2), ...
            round(xmax));

    ymin = ...
        max( ...
            1, ...
            round(ymin));

    ymax = ...
        min( ...
            size(I,1), ...
            round(ymax));

    if xmax < xmin || ...
            ymax < ymin

        return;
    end

    cropImg = ...
        I( ...
            ymin:ymax, ...
            xmin:xmax);

    ax = ...
        getappdata( ...
            fig, ...
            'axROI');

    if isempty(ax) || ...
            ~ishghandle(ax)

        return;
    end

    %==============================================================
    % PREMIERE FRAME : CREER L'AFFICHAGE
    %==============================================================

    hImg = [];

    if isappdata(fig,'roi_movie_hImg')

        hImg = ...
            getappdata( ...
                fig, ...
                'roi_movie_hImg');
    end

    if initialize_display || ...
            isempty(hImg) || ...
            ~ishghandle(hImg)

        cla(ax);

        hImg = ...
            imagesc( ...
                ax, ...
                cropImg);

        setappdata( ...
            fig, ...
            'roi_movie_hImg', ...
            hImg);

        colormap(ax,gray);
        axis(ax,'image');

        set( ...
            ax, ...
            'YDir', ...
            'reverse');

        %==========================================================
        % CONTRASTE FIXE POUR TOUT LE FILM
        %==========================================================

        v = ...
            cropImg( ...
                isfinite(cropImg));

        if ~isempty(v)

            lo = ...
                prctile( ...
                    v, ...
                    1);

            hi = ...
                prctile( ...
                    v, ...
                    99.5);

            if ~isfinite(lo) || ...
                    ~isfinite(hi) || ...
                    hi <= lo

                lo = min(v);
                hi = max(v);
            end

            if isfinite(lo) && ...
                    isfinite(hi) && ...
                    hi > lo

                clim( ...
                    ax, ...
                    [lo hi]);

                setappdata( ...
                    fig, ...
                    'roi_movie_clim', ...
                    [lo hi]);
            end
        end

        hold(ax,'on');

        %==========================================================
        % OUTLINE DE LA CELLULE COURANTE
        %==========================================================

        cid = ...
            getappdata( ...
                fig, ...
                'cell_id');

        outline_x = [];
        outline_y = [];

        if isappdata(fig,'outlines_x') && ...
                isappdata(fig,'outlines_y')

            outlines_x = ...
                getappdata( ...
                    fig, ...
                    'outlines_x');

            outlines_y = ...
                getappdata( ...
                    fig, ...
                    'outlines_y');

            if iscell(outlines_x) && ...
                    iscell(outlines_y) && ...
                    cid >= 1 && ...
                    cid <= numel(outlines_x) && ...
                    cid <= numel(outlines_y)

                outline_x = ...
                    outlines_x{cid};

                outline_y = ...
                    outlines_y{cid};
            end
        end

        if ~isempty(outline_x) && ...
                ~isempty(outline_y)

            outline_x = ...
                double( ...
                    outline_x(:));

            outline_y = ...
                double( ...
                    outline_y(:));

            n = ...
                min( ...
                    numel(outline_x), ...
                    numel(outline_y));

            outline_x = ...
                outline_x(1:n);

            outline_y = ...
                outline_y(1:n);

            good = ...
                isfinite(outline_x) & ...
                isfinite(outline_y);

            outline_x = ...
                outline_x(good);

            outline_y = ...
                outline_y(good);

            if ~isempty(outline_x)

                outline_x_crop = ...
                    outline_x - xmin + 1;

                outline_y_crop = ...
                    outline_y - ymin + 1;

                plot( ...
                    ax, ...
                    outline_x_crop, ...
                    outline_y_crop, ...
                    'r-', ...
                    'LineWidth', ...
                    1.5);
            end
        end

        %==========================================================
        % SCALE BAR
        %==========================================================

        pixel_size_um = NaN;

        if isappdata(fig,'pixel_size_um')

            pixel_size_um = ...
                getappdata( ...
                    fig, ...
                    'pixel_size_um');
        end

        add_scale_bar( ...
            ax, ...
            pixel_size_um);

        hold(ax,'off');

    else

        %==========================================================
        % FRAMES SUIVANTES : UNIQUEMENT CData
        %==========================================================

        set( ...
            hImg, ...
            'CData', ...
            cropImg);
    end

    %==============================================================
    % TITRE
    %==============================================================

    cid = ...
        getappdata( ...
            fig, ...
            'cell_id');

    title( ...
        ax, ...
        sprintf( ...
            'Cellule %d | frame %d / %d', ...
            cid, ...
            frame_index, ...
            movie_data.nFrames), ...
        'Interpreter', ...
        'none');

    setappdata( ...
        fig, ...
        'roi_movie_frame', ...
        frame_index);

    drawnow limitrate;

    %==============================================================
    % La frame du plan p est decalee de (p-1)/fs_motion dans le
    % temps global ; aucun second curseur propre a la ROI.
    %==============================================================

    fs_plane = getappdata(fig,'fs_plane');
    fs_motion = getappdata(fig,'fs_motion');
    plane = getappdata(fig,'plane');
    t_movie = (plane-1)/fs_motion + (frame_index-1)/fs_plane;
    update_shared_movie_cursor(fig,t_movie);
end

function click_movie_graph(fig)
    % Clic gauche sur les graphiques : deplacer le curseur commun et
    % actualiser la camera deja integree au Viewer, sans lecture.
    if ~ishghandle(fig) || ~strcmp(get(fig,'SelectionType'),'normal')
        return;
    end

    clicked = hittest(fig);
    if isempty(clicked) || ~isgraphics(clicked)
        return;
    end

    if strcmp(get(clicked,'Type'),'axes')
        ax = clicked;
    else
        ax = ancestor(clicked,'axes');
    end

    if isempty(ax) || ~isgraphics(ax)
        return;
    end

    allowed_axes = [getappdata(fig,'ax1'),getappdata(fig,'axF0'), ...
                    getappdata(fig,'axDev'),getappdata(fig,'axMotion'), ...
                    getappdata(fig,'axRaster')];
    if ~any(ax == allowed_axes)
        return;
    end

    cp = get(ax,'CurrentPoint');
    t_click = cp(1,1);
    y_click = cp(1,2);
    xl = xlim(ax);
    yl = ylim(ax);

    if ~isfinite(t_click) || ~isfinite(y_click) || ...
            t_click < min(xl) || t_click > max(xl) || ...
            y_click < min(yl) || y_click > max(yl)
        return;
    end

    pause_roi_movie(fig);
    pause_behavior_movie(fig);
    setappdata(fig,'speed_active_stop_time',[]);
    setappdata(fig,'speed_active_last_onset_time',[]);

    % Aucune ouverture de fenetre : la camera est deja dans le Viewer.
    restore_embedded_mean_image(fig);
    seek_shared_movie_time(fig,t_click);
end

function seek_shared_movie_time(fig,t_requested)
    % Deux frequences, un temps global. On affiche la frame la plus
    % proche dans chaque film puis UN seul curseur au temps demande.
    if ~ishghandle(fig) || ~isscalar(t_requested) || ~isfinite(t_requested)
        return;
    end

    fs_plane = getappdata(fig,'fs_plane');
    fs_motion = getappdata(fig,'fs_motion');
    plane = getappdata(fig,'plane');
    if ~isscalar(fs_plane) || ~isfinite(fs_plane) || fs_plane<=0 || ...
            ~isscalar(fs_motion) || ~isfinite(fs_motion) || fs_motion<=0 || ...
            ~isscalar(plane) || ~isfinite(plane)
        return;
    end

    plane_offset = (plane-1)/fs_motion;
    t_min = -Inf;
    t_max = Inf;
    roi_data = [];
    behavior_data = [];

    % Le movie ROI est indexe une seule fois, si le crop est disponible.
    crop = getappdata(fig,'roi_crop_bounds');
    if ~isempty(crop) && numel(crop)==4
        roi_data = getappdata(fig,'roi_movie_data');
        if isempty(roi_data)
            suite2p_path = getappdata(fig,'suite2p_path');
            if ~isempty(suite2p_path) && ...
                    isfolder(fullfile(char(string(suite2p_path)),'reg_tif'))
                roi_data = get_roi_movie_data(fig);
            end
        end
        if ~isempty(roi_data) && roi_data.nFrames>=1
            t_min = max(t_min,plane_offset);
            t_max = min(t_max,plane_offset+(roi_data.nFrames-1)/fs_plane);
        else
            roi_data = [];
        end
    end

    behavior_data = getappdata(fig,'behavior_movie_data');
    if isempty(behavior_data)
        movie_path = getappdata(fig,'behavior_movie_path');
        if ~isempty(movie_path) && isfile(movie_path)
            behavior_data = get_behavior_movie_data(fig);
        end
    end
    if ~isempty(behavior_data) && behavior_data.nFrames>=1
        t_min = max(t_min,0);
        t_max = min(t_max,(behavior_data.nFrames-1)/fs_motion);
    else
        behavior_data = [];
    end

    if isempty(roi_data) && isempty(behavior_data)
        return;
    end

    % S'il n'y a pas de recouvrement, ne pas inventer de synchronisation.
    if t_max < t_min
        return;
    end

    t_requested = max(t_min,min(t_max,t_requested));
    setappdata(fig,'shared_movie_max_time',t_max);

    if ~isempty(roi_data) && getappdata(fig,'roi_movie_visible')
        roi_idx = round((t_requested-plane_offset)*fs_plane)+1;
        roi_idx = max(1,min(roi_data.nFrames,roi_idx));
        h_roi = getappdata(fig,'roi_movie_hImg');
        current_roi = getappdata(fig,'roi_movie_frame');
        if isempty(current_roi) || current_roi~=roi_idx || ...
                isempty(h_roi) || ~isgraphics(h_roi)
            show_roi_movie_frame(fig,roi_idx, ...
                isempty(h_roi) || ~isgraphics(h_roi));
        end
    end

    if ~isempty(behavior_data)
        behavior_idx = round(t_requested*fs_motion)+1;
        behavior_idx = max(1,min(behavior_data.nFrames,behavior_idx));
        h_behavior = getappdata(fig,'behavior_movie_hImg');
        current_behavior = getappdata(fig,'behavior_movie_frame');
        if isempty(current_behavior) || current_behavior~=behavior_idx || ...
                isempty(h_behavior) || ~isgraphics(h_behavior)
            show_behavior_movie_frame(fig,behavior_idx, ...
                isempty(h_behavior) || ~isgraphics(h_behavior));
        end
    end

    % Les deux frames sont quantifiees sur des grilles differentes.
    % Ne pas laisser la derniere lecture choisir une deuxieme ligne.
    update_shared_movie_cursor(fig,t_requested);
    % Meme titre de frame a l'arret, bien que l'axe affiche la moyenne.
    if getappdata(fig,'viewer_mode') && ...
            ~getappdata(fig,'roi_movie_visible') && ...
            ~isempty(getappdata(fig,'roi_crop_bounds'))
        update_viewer_roi_title(fig);
    end
end

function update_shared_movie_cursor(fig,t_global)
    % Un unique marqueur temporel commun sur les quatre axes.
    if ~ishghandle(fig) || ~isscalar(t_global) || ~isfinite(t_global)
        return;
    end

    setappdata(fig,'shared_movie_time',t_global);
    axes_fields = {'ax1','axF0','axDev','axMotion','axRaster'};
    cursor_fields = {'shared_movie_cursor','shared_movie_cursor_f0', ...
                     'shared_movie_cursor_dev','shared_movie_cursor_motion', ...
                     'shared_movie_cursor_raster'};

    for k=1:numel(axes_fields)
        ax = getappdata(fig,axes_fields{k});
        if isempty(ax) || ~isgraphics(ax)
            continue;
        end

        h = getappdata(fig,cursor_fields{k});
        if isempty(h) || ~isgraphics(h)
            h = xline(ax,t_global,'r-','LineWidth',1.6);
            set(h,'HitTest','off','PickableParts','none');
            setappdata(fig,cursor_fields{k},h);
        else
            h.Value = t_global;
        end
    end
end

%% ===================== BEHAVIOR MOVIE =====================

function toggle_behavior_movie(fig)

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    playing = ...
        isappdata(fig,'behavior_movie_playing') && ...
        getappdata(fig,'behavior_movie_playing');

    %==============================================================
    % PAUSE
    %==============================================================

    if playing

        pause_behavior_movie(fig);
        return;
    end

    %==============================================================
    % OUVRIR LE TIFF SI NECESSAIRE
    %==============================================================

    movie_data = ...
        get_behavior_movie_data(fig);

    if isempty(movie_data)

        fprintf( ...
            'Behavior movie: cam_crop.tif indisponible.\n');

        return;
    end

    if ~isfield(movie_data,'nFrames') || ...
            isempty(movie_data.nFrames) || ...
            ~isfinite(movie_data.nFrames) || ...
            movie_data.nFrames <= 1

        warning( ...
            'peak_detection_tuner:BehaviorMovieSingleFrame', ...
            ['Behavior movie: une seule frame est autorisee. ' ...
             'Verifier behavior_frame_limit dans run_gcamp_peak_detection.']);

        return;
    end

    %==============================================================
    %==============================================================
    % Reprendre au temps global commun et synchroniser la ROI.
    t_start = getappdata(fig,'shared_movie_time');
    if isempty(t_start) || ~isfinite(t_start)
        t_start = 0;
    end

    pause_roi_movie(fig); % le timer camera devient le seul maitre
    seek_shared_movie_time(fig,t_start);
    frame_idx = getappdata(fig,'behavior_movie_frame');

    % Replay depuis le debut de l'intervalle commun, meme si le film
    % calcique se termine avant le film comportemental.
    t_max = getappdata(fig,'shared_movie_max_time');
    if ~isempty(t_max) && isfinite(t_max) && ...
            getappdata(fig,'shared_movie_time') >= t_max - 1e-9
        fs_motion = getappdata(fig,'fs_motion');
        plane = getappdata(fig,'plane');
        t_first = 0;
        if ~isempty(getappdata(fig,'roi_crop_bounds')) && ...
                ~isempty(getappdata(fig,'roi_movie_data'))
            t_first = (plane-1)/fs_motion;
        end
        seek_shared_movie_time(fig,t_first);
        frame_idx = getappdata(fig,'behavior_movie_frame');
    end

    %==============================================================
    % FREQUENCE CAMERA / MOTION
    %==============================================================

    fs_motion = ...
        getappdata( ...
            fig, ...
            'fs_motion');

    if isempty(fs_motion) || ...
            ~isfinite(fs_motion) || ...
            fs_motion <= 0

        fs_motion = 10;
    end

    % Le timer peut etre legerement plus lent que le framerate reel :
    % advance_behavior_movie recalcule la frame cible avec toc() et
    % saute les frames necessaires si la lecture disque prend du retard.
    period_sec = ...
        max( ...
            0.02, ...
            1 / fs_motion);

    %==============================================================
    % SUPPRIMER ANCIEN TIMER
    %==============================================================

    old_timer = [];

    if isappdata(fig,'behavior_movie_timer')

        old_timer = ...
            getappdata( ...
                fig, ...
                'behavior_movie_timer');
    end

    if ~isempty(old_timer)

        try
            stop(old_timer);
        catch
        end

        try
            delete(old_timer);
        catch
        end
    end

    %==============================================================
    % BASE TEMPORELLE DU PLAY
    %==============================================================

    setappdata( ...
        fig, ...
        'behavior_movie_start_frame', ...
        frame_idx);

    setappdata( ...
        fig, ...
        'behavior_movie_start_tic', ...
        tic);

    %==============================================================
    % TIMER CAMERA : seul timer actif, la ROI suit son temps.
    %==============================================================

    movie_timer = ...
        timer( ...
            'ExecutionMode', ...
            'fixedRate', ...
            'Period', ...
            period_sec, ...
            'BusyMode', ...
            'drop', ...
            'TimerFcn', ...
            @(~,~) advance_behavior_movie(fig));

    setappdata( ...
        fig, ...
        'behavior_movie_timer', ...
        movie_timer);

    setappdata( ...
        fig, ...
        'behavior_movie_playing', ...
        true);

    update_shared_movie_button(fig);

    fprintf( ...
        'Behavior movie: play frame %d / %d | %.3f Hz.\n', ...
        frame_idx, ...
        movie_data.nFrames, ...
        fs_motion);

    try
        start(movie_timer);
    catch ME
        setappdata(fig,'behavior_movie_playing',false);

        update_shared_movie_button(fig);

        warning( ...
            'peak_detection_tuner:BehaviorTimerStartFailed', ...
            'Impossible de demarrer le timer comportemental : %s', ...
            ME.message);
    end
end


function advance_behavior_movie(fig)

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    if ~isappdata(fig,'behavior_movie_playing') || ...
            ~getappdata(fig,'behavior_movie_playing')

        return;
    end

    movie_data = ...
        get_behavior_movie_data(fig);

    if isempty(movie_data)

        pause_behavior_movie(fig);
        restore_embedded_mean_image(fig);
        return;
    end

    fs_motion = ...
        getappdata( ...
            fig, ...
            'fs_motion');

    if isempty(fs_motion) || ...
            ~isfinite(fs_motion) || ...
            fs_motion <= 0

        fs_motion = 10;
    end

    start_frame = 1;

    if isappdata(fig,'behavior_movie_start_frame')

        start_frame = ...
            getappdata( ...
                fig, ...
                'behavior_movie_start_frame');
    end

    start_tic = [];

    if isappdata(fig,'behavior_movie_start_tic')

        start_tic = ...
            getappdata( ...
                fig, ...
                'behavior_movie_start_tic');
    end

    if isempty(start_tic)

        start_tic = tic;

        setappdata( ...
            fig, ...
            'behavior_movie_start_tic', ...
            start_tic);
    end

    elapsed_sec = ...
        toc(start_tic);

    frame_idx = ...
        start_frame + ...
        floor( ...
            elapsed_sec * ...
            fs_motion);

    current_frame = 1;

    if isappdata(fig,'behavior_movie_frame')

        current_frame = ...
            getappdata( ...
                fig, ...
                'behavior_movie_frame');
    end

    % Pas de nouvelle lecture si la frame cible n'a pas change.
    if frame_idx <= current_frame
        return;
    end

    t_next = (frame_idx-1)/fs_motion;
    if stop_at_speed_active_end(fig,t_next)
        return;
    end

    %==============================================================
    % FIN DE LA PERIODE AUTORISEE
    %==============================================================

    if frame_idx > movie_data.nFrames

        if current_frame < movie_data.nFrames

            seek_shared_movie_time(fig,(movie_data.nFrames-1)/fs_motion);
        end

        setappdata( ...
            fig, ...
            'behavior_movie_frame', ...
            movie_data.nFrames);

        pause_behavior_movie(fig);
        restore_embedded_mean_image(fig);
        return;
    end

    %==============================================================
    % LIRE DIRECTEMENT LA FRAME CIBLE
    %==============================================================

    t_max = getappdata(fig,'shared_movie_max_time');
    if ~isempty(t_max) && t_next > t_max + 1e-9
        pause_behavior_movie(fig);
        restore_embedded_mean_image(fig);
        return;
    end

    seek_shared_movie_time(fig,t_next);
    ok = getappdata(fig,'behavior_movie_frame') == frame_idx;

    if ~ok

        % Le TIFF peut etre plus court que la limite temporelle estimee.
        % Dans ce cas on s'arrete proprement a la derniere frame lisible.
        movie_data.nFrames = ...
            max( ...
                1, ...
                current_frame);

        setappdata( ...
            fig, ...
            'behavior_movie_data', ...
            movie_data);

        pause_behavior_movie(fig);
        restore_embedded_mean_image(fig);
    end
end


function pause_behavior_movie(fig)

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    movie_timer = [];

    if isappdata(fig,'behavior_movie_timer')

        movie_timer = ...
            getappdata( ...
                fig, ...
                'behavior_movie_timer');
    end

    if ~isempty(movie_timer)

        try
            stop(movie_timer);
        catch
        end
    end

    setappdata( ...
        fig, ...
        'behavior_movie_playing', ...
        false);

    update_shared_movie_button(fig);
end


function reset_behavior_movie_display( ...
        fig, ...
        close_tiff)

    if nargin < 2
        close_tiff = false;
    end

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    %==============================================================
    % TIMER
    %==============================================================

    movie_timer = [];

    if isappdata(fig,'behavior_movie_timer')

        movie_timer = ...
            getappdata( ...
                fig, ...
                'behavior_movie_timer');
    end

    if ~isempty(movie_timer)

        try
            stop(movie_timer);
        catch
        end

        try
            delete(movie_timer);
        catch
        end
    end

    setappdata(fig,'behavior_movie_timer',[]);
    setappdata(fig,'behavior_movie_playing',false);
    setappdata(fig,'behavior_movie_start_tic',[]);

    %==============================================================
    % TIFF
    %==============================================================

    if close_tiff && ...
            isappdata(fig,'behavior_movie_tiff')

        tifObj = ...
            getappdata( ...
                fig, ...
                'behavior_movie_tiff');

        if ~isempty(tifObj)

            try
                close(tifObj);
            catch
            end
        end

        setappdata(fig,'behavior_movie_tiff',[]);

        if isappdata(fig,'behavior_movie_fid')

            fid = ...
                getappdata( ...
                    fig, ...
                    'behavior_movie_fid');

            if ~isempty(fid) && ...
                    isscalar(fid) && ...
                    fid >= 0

                try
                    fclose(fid);
                catch
                end
            end
        end

        setappdata(fig,'behavior_movie_fid',[]);
        setappdata(fig,'behavior_movie_data',[]);
    end

    update_shared_movie_button(fig);
end


function movie_data = get_behavior_movie_data(fig)

    movie_data = [];

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    %==============================================================
    % DEJA OUVERT
    %==============================================================

    if isappdata(fig,'behavior_movie_data')

        saved_data = ...
            getappdata( ...
                fig, ...
                'behavior_movie_data');

        if ~isempty(saved_data) && ...
                isstruct(saved_data) && ...
                isfield(saved_data,'nFrames') && ...
                saved_data.nFrames >= 1

            movie_data = ...
                saved_data;

            return;
        end
    end

    %==============================================================
    % PATH
    %==============================================================

    if ~isappdata(fig,'behavior_movie_path')
        return;
    end

    movie_path = ...
        getappdata( ...
            fig, ...
            'behavior_movie_path');

    if isempty(movie_path) || ...
            exist(movie_path,'file') ~= 2

        return;
    end

    %==============================================================
    % LIMITE TEMPORELLE DEMANDEE
    %==============================================================

    nFrames = [];

    if isappdata(fig,'behavior_frame_limit')

        nFrames = ...
            getappdata( ...
                fig, ...
                'behavior_frame_limit');
    end

    if isempty(nFrames) || ...
            ~isfinite(nFrames) || ...
            nFrames < 1

        nFrames = 1;
    end

    nFrames = ...
        max( ...
            1, ...
            round(nFrames));

    %==============================================================
    % OUVRIR LE PREMIER IFD
    %
    % Fiji/ImageJ peut sauvegarder les grosses piles (>4 Go) sous
    % forme de stack contigue : une seule directory TIFF decrivant
    % la premiere image, puis toutes les images stockees a la suite.
    % Dans ce cas nextDirectory() echoue meme si le film contient
    % des milliers de frames.
    %==============================================================

    try

        tifObj = ...
            Tiff( ...
                movie_path, ...
                'r');

    catch ME

        warning( ...
            'peak_detection_tuner:BehaviorTiffOpenFailed', ...
            'Impossible d''ouvrir cam_crop.tif : %s', ...
            ME.message);

        return;
    end

    %==============================================================
    % METADONNEES DU PREMIER IFD
    %==============================================================

    try
        imageHeight = ...
            double( ...
                getTag( ...
                    tifObj, ...
                    'ImageLength'));

        imageWidth = ...
            double( ...
                getTag( ...
                    tifObj, ...
                    'ImageWidth'));
    catch ME

        try
            close(tifObj);
        catch
        end

        warning( ...
            'peak_detection_tuner:BehaviorTiffMetadataFailed', ...
            'Impossible de lire les dimensions de cam_crop.tif : %s', ...
            ME.message);

        return;
    end

    samplesPerPixel = 1;

    try
        samplesPerPixel = ...
            double( ...
                getTag( ...
                    tifObj, ...
                    'SamplesPerPixel'));
    catch
    end

    bitsPerSample = 8;

    try
        bitsPerSample = ...
            double( ...
                getTag( ...
                    tifObj, ...
                    'BitsPerSample'));
    catch
    end

    if numel(bitsPerSample) > 1
        bitsPerSample = bitsPerSample(1);
    end

    sampleFormat = 1;

    try
        sampleFormat = ...
            double( ...
                getTag( ...
                    tifObj, ...
                    'SampleFormat'));
    catch
    end

    if numel(sampleFormat) > 1
        sampleFormat = sampleFormat(1);
    end

    compression = 1;

    try
        compression = ...
            double( ...
                getTag( ...
                    tifObj, ...
                    'Compression'));
    catch
    end

    description = '';

    try
        description = ...
            getTag( ...
                tifObj, ...
                'ImageDescription');
    catch
    end

    %==============================================================
    % NOMBRE DE FRAMES DECLARE PAR IMAGEJ
    %==============================================================

    nFramesImageJ = [];

    if ~isempty(description)

        token = ...
            regexp( ...
                char(description), ...
                'images=(\d+)', ...
                'tokens', ...
                'once');

        if ~isempty(token)

            nFramesImageJ = ...
                str2double( ...
                    token{1});

            if isfinite(nFramesImageJ) && ...
                    nFramesImageJ >= 1

                nFrames = ...
                    min( ...
                        nFrames, ...
                        round(nFramesImageJ));
            end
        end
    end

    %==============================================================
    % TEST : TIFF MULTI-IFD CLASSIQUE OU STACK IMAGEJ CONTIGUE ?
    %==============================================================

    has_second_ifd = false;

    try

        nextDirectory(tifObj);

        has_second_ifd = true;

        setDirectory( ...
            tifObj, ...
            1);

    catch

        has_second_ifd = false;

        try
            setDirectory( ...
                tifObj, ...
                1);
        catch
        end
    end

    movie_data = ...
        struct();

    movie_data.path = ...
        movie_path;

    movie_data.nFrames = ...
        nFrames;

    movie_data.height = ...
        imageHeight;

    movie_data.width = ...
        imageWidth;

    movie_data.samplesPerPixel = ...
        samplesPerPixel;

    %==============================================================
    % CAS 1 : TIFF MULTI-IFD CLASSIQUE
    %==============================================================

    if has_second_ifd

        movie_data.reader_mode = ...
            'ifd';

        setappdata( ...
            fig, ...
            'behavior_movie_tiff', ...
            tifObj);

        setappdata( ...
            fig, ...
            'behavior_movie_fid', ...
            []);

        fprintf( ...
            ['Behavior movie: TIFF multi-IFD classique, ' ...
             '%d frames autorisees.\n'], ...
            movie_data.nFrames);

    %==============================================================
    % CAS 2 : STACK IMAGEJ CONTIGUE
    %==============================================================

    else

        %----------------------------------------------------------
        % La lecture brute n'est correcte que si les pixels sont
        % non compresses. Les cam_crop.tif ImageJ sont normalement
        % en TIFF non compresse.
        %----------------------------------------------------------

        if compression ~= 1

            try
                close(tifObj);
            catch
            end

            warning( ...
                'peak_detection_tuner:BehaviorContiguousCompressed', ...
                ['cam_crop.tif est une pile ImageJ contigue mais ' ...
                 'compressee. Lecture directe impossible ' ...
                 '(Compression=%d).'], ...
                compression);

            return;
        end

        stripOffsets = [];
        stripByteCounts = [];

        try
            stripOffsets = ...
                double( ...
                    getTag( ...
                        tifObj, ...
                        'StripOffsets'));
        catch
        end

        try
            stripByteCounts = ...
                double( ...
                    getTag( ...
                        tifObj, ...
                        'StripByteCounts'));
        catch
        end

        if isempty(stripOffsets)

            try
                close(tifObj);
            catch
            end

            warning( ...
                'peak_detection_tuner:BehaviorStripOffsetMissing', ...
                'Impossible de determiner StripOffsets dans cam_crop.tif.');

            return;
        end

        %----------------------------------------------------------
        % Classe MATLAB des pixels
        % SampleFormat TIFF :
        %   1 = unsigned integer
        %   2 = signed integer
        %   3 = IEEE floating point
        %----------------------------------------------------------

        matlabClass = '';

        switch sampleFormat

            case 1

                switch bitsPerSample
                    case 8
                        matlabClass = 'uint8';
                    case 16
                        matlabClass = 'uint16';
                    case 32
                        matlabClass = 'uint32';
                end

            case 2

                switch bitsPerSample
                    case 8
                        matlabClass = 'int8';
                    case 16
                        matlabClass = 'int16';
                    case 32
                        matlabClass = 'int32';
                end

            case 3

                switch bitsPerSample
                    case 32
                        matlabClass = 'single';
                    case 64
                        matlabClass = 'double';
                end
        end

        if isempty(matlabClass)

            try
                close(tifObj);
            catch
            end

            warning( ...
                'peak_detection_tuner:BehaviorPixelTypeUnsupported', ...
                ['Type pixel TIFF non gere : SampleFormat=%d, ' ...
                 'BitsPerSample=%d.'], ...
                sampleFormat, ...
                bitsPerSample);

            return;
        end

        %----------------------------------------------------------
        % Byte order du fichier TIFF
        %----------------------------------------------------------

        fid_header = ...
            fopen( ...
                movie_path, ...
                'r');

        if fid_header < 0

            try
                close(tifObj);
            catch
            end

            warning( ...
                'peak_detection_tuner:BehaviorRawOpenFailed', ...
                'Impossible d''ouvrir cam_crop.tif en lecture brute.');

            return;
        end

        byte_signature = ...
            fread( ...
                fid_header, ...
                2, ...
                '*uint8');

        fclose(fid_header);

        if isequal( ...
                byte_signature(:).', ...
                [73 73])

            machineFormat = ...
                'ieee-le';

        elseif isequal( ...
                byte_signature(:).', ...
                [77 77])

            machineFormat = ...
                'ieee-be';

        else

            machineFormat = ...
                'native';
        end

        bytesPerSample = ...
            bitsPerSample / 8;

        pixelsPerFrame = ...
            imageWidth * ...
            imageHeight * ...
            samplesPerPixel;

        frameBytes = ...
            pixelsPerFrame * ...
            bytesPerSample;

        pixelDataOffset = ...
            stripOffsets(1);

        %----------------------------------------------------------
        % Verification simple du premier IFD
        %----------------------------------------------------------

        if ~isempty(stripByteCounts)

            firstFrameBytes = ...
                sum( ...
                    stripByteCounts(:));

            if firstFrameBytes ~= frameBytes

                fprintf( ...
                    ['Behavior movie: note - StripByteCounts=%g, ' ...
                     'frameBytes=%g. Lecture ImageJ contigue tentee.\n'], ...
                    firstFrameBytes, ...
                    frameBytes);
            end
        end

        try
            close(tifObj);
        catch
        end

        fid = ...
            fopen( ...
                movie_path, ...
                'r', ...
                machineFormat);

        if fid < 0

            warning( ...
                'peak_detection_tuner:BehaviorRawOpenFailed', ...
                'Impossible d''ouvrir cam_crop.tif en lecture brute.');

            return;
        end

        movie_data.reader_mode = ...
            'imagej_contiguous';

        movie_data.pixelDataOffset = ...
            pixelDataOffset;

        movie_data.frameBytes = ...
            frameBytes;

        movie_data.pixelsPerFrame = ...
            pixelsPerFrame;

        movie_data.matlabClass = ...
            matlabClass;

        movie_data.machineFormat = ...
            machineFormat;

        setappdata( ...
            fig, ...
            'behavior_movie_tiff', ...
            []);

        setappdata( ...
            fig, ...
            'behavior_movie_fid', ...
            fid);

        fprintf( ...
            ['Behavior movie: pile ImageJ contigue detectee, ' ...
             'lecture brute frame par frame, %d frames autorisees'], ...
            movie_data.nFrames);

        if ~isempty(nFramesImageJ) && ...
                isfinite(nFramesImageJ)

            fprintf( ...
                ' (%d declarees par ImageJ)', ...
                round(nFramesImageJ));
        end

        fprintf('.\n');
    end

    setappdata( ...
        fig, ...
        'behavior_movie_data', ...
        movie_data);
end


function ok = show_behavior_movie_frame( ...
        fig, ...
        frame_index, ...
        initialize_display)

    ok = false;

    if isempty(fig) || ...
            ~ishghandle(fig)

        return;
    end

    movie_data = ...
        get_behavior_movie_data(fig);

    if isempty(movie_data) || ...
            ~isstruct(movie_data) || ...
            ~isfield(movie_data,'reader_mode')

        return;
    end

    frame_index = ...
        max( ...
            1, ...
            min( ...
                round(frame_index), ...
                movie_data.nFrames));

    %==============================================================
    % LIRE UNE SEULE FRAME
    %==============================================================

    I = [];

    try

        switch movie_data.reader_mode

            %======================================================
            % TIFF MULTI-IFD CLASSIQUE
            %======================================================

            case 'ifd'

                if ~isappdata(fig,'behavior_movie_tiff')
                    return;
                end

                tifObj = ...
                    getappdata( ...
                        fig, ...
                        'behavior_movie_tiff');

                if isempty(tifObj)
                    return;
                end

                setDirectory( ...
                    tifObj, ...
                    frame_index);

                I = ...
                    read(tifObj);

            %======================================================
            % TIFF IMAGEJ CONTIGU
            %======================================================

            case 'imagej_contiguous'

                if ~isappdata(fig,'behavior_movie_fid')
                    return;
                end

                fid = ...
                    getappdata( ...
                        fig, ...
                        'behavior_movie_fid');

                if isempty(fid) || ...
                        ~isscalar(fid) || ...
                        fid < 0

                    return;
                end

                frameOffset = ...
                    movie_data.pixelDataOffset + ...
                    (frame_index - 1) * ...
                    movie_data.frameBytes;

                status = ...
                    fseek( ...
                        fid, ...
                        frameOffset, ...
                        'bof');

                if status ~= 0

                    error( ...
                        'Impossible de positionner le fichier a l''offset %g.', ...
                        frameOffset);
                end

                raw = ...
                    fread( ...
                        fid, ...
                        movie_data.pixelsPerFrame, ...
                        ['*' movie_data.matlabClass]);

                if numel(raw) ~= ...
                        movie_data.pixelsPerFrame

                    error( ...
                        ['Frame %d incomplete : %d pixels lus / %d ' ...
                         'attendus.'], ...
                        frame_index, ...
                        numel(raw), ...
                        movie_data.pixelsPerFrame);
                end

                if movie_data.samplesPerPixel == 1

                    % TIFF stocke les pixels ligne par ligne.
                    % fread/reshape MATLAB est column-major : transposer
                    % apres reshape [width x height].
                    I = ...
                        reshape( ...
                            raw, ...
                            [ ...
                                movie_data.width, ...
                                movie_data.height ...
                            ]).';

                else

                    I = ...
                        reshape( ...
                            raw, ...
                            [ ...
                                movie_data.samplesPerPixel, ...
                                movie_data.width, ...
                                movie_data.height ...
                            ]);

                    I = ...
                        permute( ...
                            I, ...
                            [3 2 1]);
                end

            otherwise

                return;
        end

    catch ME

        warning( ...
            'peak_detection_tuner:BehaviorFrameReadFailed', ...
            'Impossible de lire la frame comportementale %d : %s', ...
            frame_index, ...
            ME.message);

        return;
    end

    %==============================================================
    % AXE
    %==============================================================

    if ~isappdata(fig,'axBehavior')
        return;
    end

    ax = ...
        getappdata( ...
            fig, ...
            'axBehavior');

    if isempty(ax) || ...
            ~ishghandle(ax)

        return;
    end

    hImg = [];

    if isappdata(fig,'behavior_movie_hImg')

        hImg = ...
            getappdata( ...
                fig, ...
                'behavior_movie_hImg');
    end

    if initialize_display || ...
            isempty(hImg) || ...
            ~ishghandle(hImg)

        cla(ax);

        if ndims(I) == 2

            hImg = ...
                imagesc( ...
                    ax, ...
                    I);

            colormap( ...
                ax, ...
                gray(256));

            finite_values = ...
                double( ...
                    I( ...
                        isfinite(I)));

            clim_values = [];

            if ~isempty(finite_values)

                lo = ...
                    prctile( ...
                        finite_values, ...
                        1);

                hi = ...
                    prctile( ...
                        finite_values, ...
                        99);

                if isfinite(lo) && ...
                        isfinite(hi) && ...
                        hi > lo

                    clim_values = ...
                        [lo hi];

                    caxis( ...
                        ax, ...
                        clim_values);
                end
            end

            setappdata( ...
                fig, ...
                'behavior_movie_clim', ...
                clim_values);

        else

            hImg = ...
                image( ...
                    ax, ...
                    I);
        end

        axis(ax,'image');
        axis(ax,'off');

        setappdata( ...
            fig, ...
            'behavior_movie_hImg', ...
            hImg);

    else

        set( ...
            hImg, ...
            'CData', ...
            I);

        if ndims(I) == 2 && ...
                isappdata(fig,'behavior_movie_clim')

            clim_values = ...
                getappdata( ...
                    fig, ...
                    'behavior_movie_clim');

            if ~isempty(clim_values) && ...
                    numel(clim_values) == 2 && ...
                    clim_values(2) > clim_values(1)

                caxis( ...
                    ax, ...
                    clim_values);
            end
        end
    end

    %==============================================================
    % TITRE
    %==============================================================

    fs_motion = ...
        getappdata( ...
            fig, ...
            'fs_motion');

    if isempty(fs_motion) || ...
            ~isfinite(fs_motion) || ...
            fs_motion <= 0

        fs_motion = 1;
    end

    time_sec = ...
        (frame_index - 1) / ...
        fs_motion;

    title( ...
        ax, ...
        sprintf( ...
            'Comportement | frame %d / %d | %.2f s', ...
            frame_index, ...
            movie_data.nFrames, ...
            time_sec), ...
        'Interpreter', ...
        'none');

    setappdata( ...
        fig, ...
        'behavior_movie_frame', ...
        frame_index);

    % Le comportement utilise le meme curseur que la ROI.
    update_shared_movie_cursor(fig,time_sec);

    drawnow limitrate;

    ok = true;
end


