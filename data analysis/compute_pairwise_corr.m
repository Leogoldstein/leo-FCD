function [cross_corr_gcamp_gcamp, cross_corr_gcamp_mtor, cross_corr_mtor_mtor] = ...
    compute_pairwise_corr(DF, gcamp_output_folder, DF_all, mtor_indices)

    cross_corr_gcamp_gcamp = [];
    cross_corr_gcamp_mtor  = [];
    cross_corr_mtor_mtor   = [];

    try
        % --- force textes cohérents ---
        gcamp_output_folder = char(string(gcamp_output_folder));
        filePath = fullfile(gcamp_output_folder, 'results_corr.mat');

        if exist(filePath, 'file') == 2
            S = load(filePath);
        else
            S = struct();
        end

        % --- GCaMP-GCaMP ---
        if isfield(S, 'cross_corr_gcamp_gcamp') && ~isempty(S.cross_corr_gcamp_gcamp)
            cross_corr_gcamp_gcamp = S.cross_corr_gcamp_gcamp;
        else
            disp("Processing GCaMP-GCaMP correlation: " + string(filePath));

            % corrcoef exige double/single (et gère mal certains NaN)
            X = double(DF);
            % option: enlever cellules entièrement NaN
            keep = ~all(isnan(X), 2);
            X = X(keep, :);

            if size(X,1) >= 2
                cross_corr_gcamp_gcamp = corrcoef(X');  % corr entre cellules
            else
                cross_corr_gcamp_gcamp = [];
            end

            % (optionnel) sauvegarde incrémentale
            try
                cross_corr_gcamp_gcamp_to_save = cross_corr_gcamp_gcamp;
                save(filePath, 'cross_corr_gcamp_gcamp_to_save', '-v7.3');
            catch
                % pas bloquant
            end
        end

        % ----- les blocs mTOR sont commentés chez toi : ok -----

    catch ME
        % disp sécurisé (tout en string)
        disp("An error occurred for folder: " + string(gcamp_output_folder) + " - " + string(ME.message));
        % utile si tu veux la ligne exacte
        % disp(getReport(ME,'extended','hyperlinks','off'));
    end
end