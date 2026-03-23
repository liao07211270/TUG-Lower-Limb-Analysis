clear;
clc;
close all;

%% Load Data
% 匯入動作區間時間表
Timedata = readmatrix("C:\Users\peter\Downloads\TUG.csv");  % 此為本機執行之路徑，若更換至他處則需替換路徑
Timedata(:,1) = 0;
Timedata(:,10) = [];

% 時間點換成資料點
for i = 1:21
    for m = 1:8
        Time(i,m) = fix((Timedata(i,m+1) - Timedata(i,m))*128);
    end
    
    % 匯入原始數據資料
    eval(['subject', num2str(i), ' = readtable("C:\Users\peter\OneDrive\桌面\TUG測試\20251118-FS', num2str(i), '.csv");'])  % 此為本機執行之路徑，若更換至他處則需替換路徑
    eval(['r = size(subject', num2str(i), ', 1);'])
    eval(['subject', num2str(i), '_AccGyro(:,1:6)   = table2array(subject', num2str(i), '(4:r, 2:7));'])
    eval(['subject', num2str(i), '_AccGyro(:,7:12)  = table2array(subject', num2str(i), '(4:r, 16:21));'])
    eval(['subject', num2str(i), '_AccGyro(:,13:18) = table2array(subject', num2str(i), '(4:r, 30:35));'])
    eval(['subject', num2str(i), '_AccGyro(:,19:24) = table2array(subject', num2str(i), '(4:r, 44:49));'])
    eval(['subject', num2str(i), '_AccGyro(:,25:30) = table2array(subject', num2str(i), '(4:r, 58:63));'])
    
    % 二軸合成
    eval(['subject', num2str(i), '_AccGyro(:,31) = sqrt(subject', num2str(i), '_AccGyro(:,1).^2 + subject', num2str(i), '_AccGyro(:,2).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,32) = sqrt(subject', num2str(i), '_AccGyro(:,1).^2 + subject', num2str(i), '_AccGyro(:,3).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,33) = sqrt(subject', num2str(i), '_AccGyro(:,2).^2 + subject', num2str(i), '_AccGyro(:,3).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,34) = sqrt(subject', num2str(i), '_AccGyro(:,4).^2 + subject', num2str(i), '_AccGyro(:,5).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,35) = sqrt(subject', num2str(i), '_AccGyro(:,4).^2 + subject', num2str(i), '_AccGyro(:,6).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,36) = sqrt(subject', num2str(i), '_AccGyro(:,5).^2 + subject', num2str(i), '_AccGyro(:,6).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,37) = sqrt(subject', num2str(i), '_AccGyro(:,7).^2 + subject', num2str(i), '_AccGyro(:,8).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,38) = sqrt(subject', num2str(i), '_AccGyro(:,7).^2 + subject', num2str(i), '_AccGyro(:,9).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,39) = sqrt(subject', num2str(i), '_AccGyro(:,8).^2 + subject', num2str(i), '_AccGyro(:,9).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,40) = sqrt(subject', num2str(i), '_AccGyro(:,10).^2 + subject', num2str(i), '_AccGyro(:,11).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,41) = sqrt(subject', num2str(i), '_AccGyro(:,10).^2 + subject', num2str(i), '_AccGyro(:,12).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,42) = sqrt(subject', num2str(i), '_AccGyro(:,11).^2 + subject', num2str(i), '_AccGyro(:,12).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,43) = sqrt(subject', num2str(i), '_AccGyro(:,13).^2 + subject', num2str(i), '_AccGyro(:,14).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,44) = sqrt(subject', num2str(i), '_AccGyro(:,13).^2 + subject', num2str(i), '_AccGyro(:,15).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,45) = sqrt(subject', num2str(i), '_AccGyro(:,14).^2 + subject', num2str(i), '_AccGyro(:,15).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,46) = sqrt(subject', num2str(i), '_AccGyro(:,16).^2 + subject', num2str(i), '_AccGyro(:,17).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,47) = sqrt(subject', num2str(i), '_AccGyro(:,16).^2 + subject', num2str(i), '_AccGyro(:,18).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,48) = sqrt(subject', num2str(i), '_AccGyro(:,17).^2 + subject', num2str(i), '_AccGyro(:,18).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,49) = sqrt(subject', num2str(i), '_AccGyro(:,19).^2 + subject', num2str(i), '_AccGyro(:,20).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,50) = sqrt(subject', num2str(i), '_AccGyro(:,19).^2 + subject', num2str(i), '_AccGyro(:,21).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,51) = sqrt(subject', num2str(i), '_AccGyro(:,20).^2 + subject', num2str(i), '_AccGyro(:,21).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,52) = sqrt(subject', num2str(i), '_AccGyro(:,22).^2 + subject', num2str(i), '_AccGyro(:,23).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,53) = sqrt(subject', num2str(i), '_AccGyro(:,22).^2 + subject', num2str(i), '_AccGyro(:,24).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,54) = sqrt(subject', num2str(i), '_AccGyro(:,23).^2 + subject', num2str(i), '_AccGyro(:,24).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,55) = sqrt(subject', num2str(i), '_AccGyro(:,25).^2 + subject', num2str(i), '_AccGyro(:,26).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,56) = sqrt(subject', num2str(i), '_AccGyro(:,25).^2 + subject', num2str(i), '_AccGyro(:,27).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,57) = sqrt(subject', num2str(i), '_AccGyro(:,26).^2 + subject', num2str(i), '_AccGyro(:,27).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,58) = sqrt(subject', num2str(i), '_AccGyro(:,28).^2 + subject', num2str(i), '_AccGyro(:,29).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,59) = sqrt(subject', num2str(i), '_AccGyro(:,28).^2 + subject', num2str(i), '_AccGyro(:,30).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,60) = sqrt(subject', num2str(i), '_AccGyro(:,29).^2 + subject', num2str(i), '_AccGyro(:,30).^2);'])
    
    % 三軸合成
    eval(['subject', num2str(i), '_AccGyro(:,61) = sqrt(subject', num2str(i), '_AccGyro(:,1).^2 + subject', num2str(i), '_AccGyro(:,2).^2 + subject', num2str(i), '_AccGyro(:,3).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,62) = sqrt(subject', num2str(i), '_AccGyro(:,4).^2 + subject', num2str(i), '_AccGyro(:,5).^2 + subject', num2str(i), '_AccGyro(:,6).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,63) = sqrt(subject', num2str(i), '_AccGyro(:,7).^2 + subject', num2str(i), '_AccGyro(:,8).^2 + subject', num2str(i), '_AccGyro(:,9).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,64) = sqrt(subject', num2str(i), '_AccGyro(:,10).^2 + subject', num2str(i), '_AccGyro(:,11).^2 + subject', num2str(i), '_AccGyro(:,12).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,65) = sqrt(subject', num2str(i), '_AccGyro(:,13).^2 + subject', num2str(i), '_AccGyro(:,14).^2 + subject', num2str(i), '_AccGyro(:,15).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,66) = sqrt(subject', num2str(i), '_AccGyro(:,16).^2 + subject', num2str(i), '_AccGyro(:,17).^2 + subject', num2str(i), '_AccGyro(:,18).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,67) = sqrt(subject', num2str(i), '_AccGyro(:,19).^2 + subject', num2str(i), '_AccGyro(:,20).^2 + subject', num2str(i), '_AccGyro(:,21).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,68) = sqrt(subject', num2str(i), '_AccGyro(:,22).^2 + subject', num2str(i), '_AccGyro(:,23).^2 + subject', num2str(i), '_AccGyro(:,24).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,69) = sqrt(subject', num2str(i), '_AccGyro(:,25).^2 + subject', num2str(i), '_AccGyro(:,26).^2 + subject', num2str(i), '_AccGyro(:,27).^2);'])
    eval(['subject', num2str(i), '_AccGyro(:,70) = sqrt(subject', num2str(i), '_AccGyro(:,28).^2 + subject', num2str(i), '_AccGyro(:,29).^2 + subject', num2str(i), '_AccGyro(:,30).^2);'])
    
    % 做 label 標準答案
    eval(['label', num2str(i), ' = zeros(size(subject', num2str(i), '_AccGyro,1), 1);'])
    start_idx = Time(i, 1) + Time(i, 2) + 1;
    for k = 1:6
        end_idx = start_idx + Time(i, k+2) - 1;
        eval(['label', num2str(i), '(start_idx:end_idx) = k;'])
        start_idx = end_idx + 1;
    end
    eval(['subject', num2str(i), '_AccGyro(:,71) = label', num2str(i), '(:,1);'])
    % eval(['subject', num2str(i), '_AccGyro = table2array(subject', num2str(i), '_AccGyro);'])
end

%% Windowing + Feature Extraction
WS_list = [32, 48, 64, 96];
SP = 60;
for WS_idx = 1:length(WS_list)
    WS = WS_list(WS_idx);
    for i = 1:21
        eval(['NumofWindow = fix((size(subject', num2str(i), '_AccGyro, 1) - WS)/SP) + 1;'])
        eval(['FT_subject', num2str(i), ' = [];']);
        eval(['GT_subject', num2str(i), ' = [];']);
        
        for a = 1:NumofWindow
            interval = 1+(a-1)*SP : WS+(a-1)*SP;
            for g = 1:70
                eval(['FT_subject', num2str(i), '(a, 1+(g-1)*8) = mean(subject', num2str(i), '_AccGyro(interval, g));'])
                eval(['FT_subject', num2str(i), '(a, 2+(g-1)*8) = std(subject', num2str(i), '_AccGyro(interval, g));'])
                eval(['FT_subject', num2str(i), '(a, 3+(g-1)*8) = max(subject', num2str(i), '_AccGyro(interval, g));'])
                eval(['FT_subject', num2str(i), '(a, 4+(g-1)*8) = min(subject', num2str(i), '_AccGyro(interval, g));'])
                eval(['FT_subject', num2str(i), '(a, 5+(g-1)*8) = range(subject', num2str(i), '_AccGyro(interval, g));'])
                eval(['FT_subject', num2str(i), '(a, 6+(g-1)*8) = var(subject', num2str(i), '_AccGyro(interval, g));'])
                eval(['FT_subject', num2str(i), '(a, 7+(g-1)*8) = skewness(subject', num2str(i), '_AccGyro(interval, g));'])
                eval(['FT_subject', num2str(i), '(a, 8+(g-1)*8) = kurtosis(subject', num2str(i), '_AccGyro(interval, g));'])
            end
            eval(['GT_subject', num2str(i), '(a, 1) = mode(subject', num2str(i), '_AccGyro(interval, 71));'])
        end
        eval(['FT_GT_subject', num2str(i), ' = [FT_subject', num2str(i), ', GT_subject', num2str(i), '];'])
    end
    
    %% Cross Validation
    FT_GT = [];
    data_traintest_matrix = [];
    for i = 1:21
        eval(['FT_GT = [FT_GT; FT_GT_subject', num2str(i), '];'])
        eval(['L', num2str(i), ' = size(FT_GT_subject', num2str(i), ',1);'])
    end
    
    for b = 1:7
        idx_1 = (b-1)*3 + 1;
        idx_2 = (b-1)*3 + 2;
        idx_3 = (b-1)*3 + 3;
        eval(['len1 = L', num2str(idx_1), ';']);
        eval(['len2 = L', num2str(idx_2), ';']);
        eval(['len3 = L', num2str(idx_3), ';']);
        total_len = len1 + len2 + len3;
        
        eval(['data_traintest_matrix_L', num2str(b), ' = [];']);
        eval(['data_traintest_matrix_L', num2str(b), '(1:total_len, 1) = b;'])
        eval(['data_traintest_matrix = [data_traintest_matrix; data_traintest_matrix_L', num2str(b), '];'])
    end
    
    %% Machine Learning
    model_names = {'Random Forest', 'AdaBoost', 'Decision Tree'};
    for model_idx = 1:3
        TotalMatrix = zeros(7, 4);
        for b = 1:7
            test = (data_traintest_matrix == b);
            train = ~test;
            FT_GT_test = FT_GT(test, :);
            FT_GT_train = FT_GT(train, :);
            
            Train_Y = FT_GT_train(:, 561);
            Train_Y(Train_Y == 4) = 2;
            Train_Y(Train_Y == 5) = 3;
            Train_Y(Train_Y == 6) = 1;
            
            if model_idx == 1
                % 1. Random Forest
                model = fitcensemble(FT_GT_train(:, 1:560), Train_Y, 'Method', 'Bag', 'NumLearningCycles', 200, 'Learners', templateTree('MinLeafSize', 5, 'NumVariablesToSample', 30));
            elseif model_idx == 2
                % 2. AdaBoost
                model = fitcensemble(FT_GT_train(:, 1:560), Train_Y, 'Method', 'AdaBoostM2', 'NumLearningCycles', 200, 'Learners', 'Tree');
            elseif model_idx == 3
                % 3. Decision Tree
                model = fitctree(FT_GT_train(:, 1:560), Train_Y, 'MinLeafSize', 5);
            end
            
            predictmodel = predict(model, FT_GT_test(:, 1:560));
            predictpoint = [];
            for j = 1:length(predictmodel)
                predictpoint(1+(j-1)*SP : WS+(j-1)*SP, 1) = predictmodel(j, 1);
            end
            
            idx_1 = (b-1)*3 + 1;
            idx_2 = (b-1)*3 + 2;
            idx_3 = (b-1)*3 + 3;
            predictpoint = movmedian(predictpoint, 31);
            
            eval(['TrueLabel_1 = subject', num2str(idx_1), '_AccGyro(:, 71);']);
            eval(['TrueLabel_2 = subject', num2str(idx_2), '_AccGyro(:, 71);']);
            eval(['TrueLabel_3 = subject', num2str(idx_3), '_AccGyro(:, 71);']);
            Total_True_Label = [TrueLabel_1; TrueLabel_2; TrueLabel_3];
            
            RealLen = length(Total_True_Label);
            PredLen = length(predictpoint);
            
            if PredLen < RealLen
                % 預測太短 -> 補齊
                predictpoint(PredLen+1 : RealLen, 1) = predictpoint(end, 1);
            elseif PredLen > RealLen
                % 預測太長 -> 切掉 (這很重要, 因為滑動視窗通常會凸出去)
                predictpoint = predictpoint(1:RealLen, 1);
            end
            
            % 後處理
            Final_Predict = predictpoint;
            Len1 = length(TrueLabel_1);
            Len2 = length(TrueLabel_2);
            Len3 = length(TrueLabel_3);
            
            Start_Idx = [1, Len1+1, Len1+Len2+1];
            End_Idx = [Len1, Len1+Len2, Len1+Len2+Len3];
            Subj_Indices = [idx_1, idx_2, idx_3];
            
            for t = 1:3
                idx_range = Start_Idx(t) : End_Idx(t);
                segment = Final_Predict(idx_range);
                seg_len = length(segment);
                curr_subj = Subj_Indices(t);
                
                eval(['Raw_Acc = subject', num2str(curr_subj), '_AccGyro(1:length(idx_range), 61);']);
                Physical_Std = movstd(Raw_Acc, 50);
                d_seg = diff([0; segment ~= 0; 0]);
                starts = find(d_seg == 1);
                ends = find(d_seg == -1) - 1;
                
                for k = 1:length(starts)
                    blob_len = ends(k) - starts(k) + 1;
                    if blob_len < 250
                        segment(starts(k) : ends(k)) = 0;
                    end
                end
                
                Active_Indices = find(segment ~= 0);
                if ~isempty(Active_Indices)
                    Model_End = Active_Indices(end);
                    Active_Start = Active_Indices(1);
                else
                    Model_End = seg_len;
                    Active_Start = 1;
                end
                
                Check_Zone = segment(max(1, Model_End - 200) : Model_End);
                Sit_Count = sum(Check_Zone == 1);
                
                if Sit_Count > 10
                    Active_End = Model_End;
                    Extend_Limit = 300;
                    for ext = 1:Extend_Limit
                        check_idx = Active_End + ext;
                        if check_idx > seg_len, break; end
                        if Physical_Std(check_idx) < 0.05
                            segment(check_idx) = 1; % 視為坐下
                            Active_End = check_idx; % 更新結束點
                        else
                            break; % 旦動了就停止
                        end
                    end
                    sit_indices = find(segment == 1);
                    Last_Sit_Start = seg_len;
                    if ~isempty(sit_indices)
                        diff_sit = diff(sit_indices);
                        break_sit = [0; find(diff_sit > 1); length(sit_indices)];
                        Last_Sit_Start = sit_indices(break_sit(end-1) + 1);
                    end
                    
                    Base_Sit_Len = 180;
                    Base_Turn_Len = 110;
                    Force_Turn_End = Last_Sit_Start - 1;
                    Force_Turn_Start = max(1, Last_Sit_Start - Base_Turn_Len);
                    Safety_Margin = 30;
                    
                    for shift = 0:(Base_Turn_Len - Safety_Margin)
                        curr_idx = Force_Turn_Start + shift;
                        if Physical_Std(curr_idx) < 0.15
                            Force_Turn_Start = curr_idx;
                            break;
                        end
                    end
                    
                    if Force_Turn_End > Active_End, Force_Turn_End = Active_End; end
                    if Force_Turn_End > Force_Turn_Start
                        segment(Force_Turn_Start : Force_Turn_End) = 3;
                    end
                    if Last_Sit_Start <= Active_End
                        segment(Last_Sit_Start : Active_End) = 1;
                    end
                    
                    SplitPoint = round(seg_len / 2);
                    turn_idx = find(segment == 3);
                    valid_turns = turn_idx(turn_idx < Force_Turn_Start);
                    
                    if ~isempty(valid_turns)
                        diff_idx = diff(valid_turns);
                        break_points = [0; find(diff_idx > 1); length(valid_turns)];
                        max_len = 0;
                        best_indices = [];
                        for k = 1:length(break_points)-1
                            p1 = break_points(k) + 1;
                            p2 = break_points(k+1);
                            if (p2 - p1 + 1) > max_len
                                max_len = p2 - p1 + 1;
                                best_indices = valid_turns(p1:p2);
                            end
                        end
                        if ~isempty(best_indices)
                            SplitPoint = best_indices(end);
                        end
                    end
                    
                    if Force_Turn_Start > SplitPoint
                        Return_Zone = (SplitPoint + 1) : (Force_Turn_Start - 1);
                        if ~isempty(Return_Zone)
                            Zone_Vals = segment(Return_Zone);
                            Noise_Idx = Return_Zone(Zone_Vals == 1);
                            segment(Noise_Idx) = 2;
                        end
                    end
                else
                    Walk_Energy_Threshold = 0.15;
                    High_Energy_Idx = find(Physical_Std > Walk_Energy_Threshold);
                    if ~isempty(High_Energy_Idx)
                        Active_End = High_Energy_Idx(end);
                    else
                        Active_End = Model_End;
                    end
                    
                    if Active_End < seg_len
                        segment(Active_End + 1 : end) = 0;
                    end
                    
                    Rescue_Sit_Len = 160;
                    Rescue_Turn_Len = 100;
                    Rescue_Sit_Start = max(Active_Start, Active_End - Rescue_Sit_Len + 1);
                    segment(Rescue_Sit_Start : Active_End) = 1;
                    
                    Rescue_Turn_End = Rescue_Sit_Start - 1;
                    Rescue_Turn_Start = max(Active_Start, Rescue_Turn_End - Rescue_Turn_Len + 1);
                    if Rescue_Turn_End > Rescue_Turn_Start
                        segment(Rescue_Turn_Start : Rescue_Turn_End) = 3;
                    end
                    
                    Force_Turn_Start = Rescue_Turn_Start;
                    SplitPoint = round(seg_len / 2);
                    turn_idx = find(segment == 3);
                    valid_turns = turn_idx(turn_idx < Force_Turn_Start);
                    
                    if ~isempty(valid_turns)
                        diff_idx = diff(valid_turns);
                        break_points = [0; find(diff_idx > 1); length(valid_turns)];
                        max_len = 0;
                        best_indices = [];
                        for k = 1:length(break_points)-1
                            p1 = break_points(k) + 1;
                            p2 = break_points(k+1);
                            if (p2 - p1 + 1) > max_len
                                max_len = p2 - p1 + 1;
                                best_indices = valid_turns(p1:p2);
                            end
                        end
                        if ~isempty(best_indices)
                            SplitPoint = best_indices(end);
                        end
                    end
                    
                    if Force_Turn_Start > SplitPoint
                        Return_Zone = (SplitPoint + 1) : (Force_Turn_Start - 1);
                        if ~isempty(Return_Zone)
                            segment(Return_Zone) = 2;
                        end
                    end
                end
                
                for k = (SplitPoint + 1) : Active_End
                    val = segment(k);
                    if val == 2
                        segment(k) = 4;
                    elseif val == 1
                        segment(k) = 6;
                    elseif val == 3
                        segment(k) = 5;
                    end
                end
                
                for k = Active_Start : SplitPoint
                    if segment(k) >= 4
                        segment(k) = 3;
                    end
                end
                
                Final_Predict(idx_range) = segment;
            end
            
            eval(['Confusionmatrix', num2str(b), ' = confusionmat(Total_True_Label, Final_Predict);'])
            eval(['matrix_size = size(Confusionmatrix', num2str(b), ', 1);'])
            eval(['Acc = sum(diag(Confusionmatrix', num2str(b), '))/sum(sum(Confusionmatrix', num2str(b), '));'])
            
            Sen = [];   
            Pre = [];  

            for i = 1:matrix_size
                eval(['Sen(i, 1) = Confusionmatrix', num2str(b), '(i,i)/sum(Confusionmatrix', num2str(b), '(i,:));'])
                eval(['Pre(1, i) = Confusionmatrix', num2str(b), '(i,i)/sum(Confusionmatrix', num2str(b), '(:,i));'])
            end
            
            P_vec = Pre';
            R_vec = Sen;
            Denominator = P_vec + R_vec;
            F1_vec = 2 * (P_vec .* R_vec) ./ Denominator;
            F1_vec(Denominator == 0) = 0;
            
            TotalMatrix(b, 1) = Acc;
            TotalMatrix(b, 2) = mean(Sen(:,1), 'omitnan');
            TotalMatrix(b, 3) = mean(Pre(1,:), 'omitnan');
            TotalMatrix(b, 4) = mean(F1_vec, 'omitnan');
            
            if model_idx == 1  % 只畫 Random Forest
            figure; 
            plot(Total_True_Label); hold on; 
            plot(Final_Predict);
            title(['WS=', num2str(WS), ' | ', model_names{model_idx}, ' | Fold=', num2str(b)]);
            legend('True', 'Pred');
            end
        end

        col_start = (model_idx - 1) * 4 + 1;
        col_end = model_idx * 4;
        total(WS_idx, col_start:col_end) = mean(TotalMatrix, 1);
    end
end

%% 圖1：三個模型比較 (WS=48)
figure('Position', [100 100 800 400]);
data_model = [total(2, 1:4)*100;    % Random Forest
              total(2, 5:8)*100;    % AdaBoost
              total(2, 9:12)*100];  % Decision Tree

b1 = bar(data_model');  % ← 轉置
b1(1).FaceColor = [0.20 0.40 0.68];
b1(2).FaceColor = [0.18 0.56 0.44];
b1(3).FaceColor = [0.45 0.45 0.42];
set(gca, 'XTickLabel', {'Accuracy','Sensitivity','Precision','F1-Score'});
ylim([50 100]);
ylabel('Score (%)');
legend('Random Forest','AdaBoost','Decision Tree','Location','southeast');
title('模型效能比較 (WS=48, SP=60)');
grid on;

%% 圖2：四種視窗大小比較（以 Random Forest 為例）
figure('Position', [100 100 800 400]);
data_ws = [total(1, 1:4)*100;   % WS=32
           total(2, 1:4)*100;   % WS=48
           total(3, 1:4)*100;   % WS=64
           total(4, 1:4)*100];  % WS=96

b2 = bar(data_ws');  % 加轉置

b2(1).FaceColor = [0.45 0.45 0.42];  % WS=32 → 灰
b2(2).FaceColor = [0.20 0.40 0.68];  % WS=48 → 藍
b2(3).FaceColor = [0.75 0.60 0.40];  % WS=64 → 淺棕
b2(4).FaceColor = [0.75 0.40 0.20];  % WS=96 → 橘
set(gca, 'XTickLabel', {'Accuracy','Sensitivity','Precision','F1-Score'});
ylim([50 100]);
ylabel('Score (%)');
legend('WS=32','WS=48','WS=64','WS=96','Location','southeast');
title('不同視窗大小效能比較 (Random Forest, SP=60)');
grid on;

%% 折線趨勢圖
figure('Position', [100 100 800 400]);
ws_values = [32, 48, 64, 96];
acc_values = total(:, 1)' * 100;  % 第1欄 = Random Forest Accuracy
plot(ws_values, acc_values, '-o', 'LineWidth', 2, 'Color', [0.20 0.40 0.68]);
xlabel('Window Size (samples)');
ylabel('Accuracy (%)');
title('視窗大小對辨識準確率的影響 (Random Forest)');
ylim([50 100]);
grid on;