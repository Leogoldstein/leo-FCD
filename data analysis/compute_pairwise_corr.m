function [cross_corr_gcamp_gcamp, cross_corr_gcamp_mtor, cross_corr_mtor_mtor] = compute_pairwise_corr(DF, gcamp_output_folder, DF_all, mtor_indices)

    cross_corr_gcamp_gcamp = [];
    cross_corr_gcamp_mtor = [];
    cross_corr_mtor_mtor = [];

    try
        filePath = fullfile(gcamp_output_folder, 'results_corr.mat');

        if exist(filePath, 'file') == 2
            data = load(filePath);
        else
            data = struct();
        end

        % --- GCaMP-GCaMP ---
        if isfield(data, 'cross_corr_gcamp_gcamp')
            cross_corr_gcamp_gcamp = data.cross_corr_gcamp_gcamp;
        else
            disp(['Processing GCaMP-GCaMP correlation: ', filePath]);
            cross_corr_gcamp_gcamp = corrcoef(DF');
        end

        % --- GCaMP-mTOR ---
        if isfield(data, 'cross_corr_gcamp_mtor')
            cross_corr_gcamp_mtor = data.cross_corr_gcamp_mtor;
        elseif ~isempty(DF_all) && ~isempty(mtor_indices) 
            disp(['Processing GCaMP-mTOR correlation: ', filePath]);
            mtor_logical = ismember(1:size(DF_all,1), mtor_indices);
            DF_mtor = DF_all(mtor_logical,:);
            DF_gcamp = DF_all(~mtor_logical,:);
            cross_corr_gcamp_mtor = corr(DF_gcamp', DF_mtor');  % utilisez corr au lieu de corrcoef
        end

        % --- mTOR-mTOR ---
        if isfield(data, 'cross_corr_mtor_mtor')
            cross_corr_mtor_mtor = data.cross_corr_mtor_mtor;
        elseif ~isempty(DF_all)
            disp(['Processing mTOR-mTOR correlation: ', filePath]);
            DF_mtor = DF_all(mtor_indices,:);
            cross_corr_mtor_mtor = corrcoef(DF_mtor');
        end

    catch ME
        disp(['An error occurred for folder: ', gcamp_output_folder, ' - ', ME.message]);
    end
end
