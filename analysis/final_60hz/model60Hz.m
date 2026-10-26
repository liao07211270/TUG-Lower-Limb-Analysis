clear;
clc;
close all;
%% Load Data
%匯入動作區間時間表
Timedata = readmatrix("C:\Users\user1\Downloads\TUG60ver\TUG60ver\TUG60Hz.csv");
Timedata(:,1)= 0;
%%Timedata(:,10)=[];

%時間點換成資料點
for i=1:21
    for m=1:8
        Time(i,m) = fix((Timedata(i,m+1) - Timedata(i,m))*60);
    end
    %匯入原始數據資料
    eval(['subject',num2str(i),'=readtable("C:\Users\user1\Downloads\TUG60ver\TUG60ver\tug',num2str(i),'.csv")'])
    eval(['r=size(subject',num2str(i),',1);'])
    eval(['subject',num2str(i),'_AccGyro(:,1:6)=subject',num2str(i),'(4:r,2:7);'])
    eval(['subject',num2str(i),'_AccGyro(:,7:12)=subject',num2str(i),'(4:r,16:21);'])
    eval(['subject',num2str(i),'_AccGyro(:,13:18)=subject',num2str(i),'(4:r,30:35);'])
    eval(['subject',num2str(i),'_AccGyro(:,19:24)=subject',num2str(i),'(4:r,44:49);'])
    eval(['subject',num2str(i),'_AccGyro(:,25:30)=subject',num2str(i),'(4:r,58:63);'])
    eval(['subject',num2str(i),'_AccGyro{:,31}=sqrt(subject',num2str(i),'_AccGyro{:,1}.^2 + subject',num2str(i),'_AccGyro{:,2}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,32}=sqrt(subject',num2str(i),'_AccGyro{:,1}.^2 + subject',num2str(i),'_AccGyro{:,3}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,33}=sqrt(subject',num2str(i),'_AccGyro{:,2}.^2 + subject',num2str(i),'_AccGyro{:,3}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,34}=sqrt(subject',num2str(i),'_AccGyro{:,4}.^2 + subject',num2str(i),'_AccGyro{:,5}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,35}=sqrt(subject',num2str(i),'_AccGyro{:,4}.^2 + subject',num2str(i),'_AccGyro{:,6}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,36}=sqrt(subject',num2str(i),'_AccGyro{:,5}.^2 + subject',num2str(i),'_AccGyro{:,6}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,37}=sqrt(subject',num2str(i),'_AccGyro{:,7}.^2 + subject',num2str(i),'_AccGyro{:,8}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,38}=sqrt(subject',num2str(i),'_AccGyro{:,7}.^2 + subject',num2str(i),'_AccGyro{:,9}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,39}=sqrt(subject',num2str(i),'_AccGyro{:,8}.^2 + subject',num2str(i),'_AccGyro{:,9}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,40}=sqrt(subject',num2str(i),'_AccGyro{:,10}.^2 + subject',num2str(i),'_AccGyro{:,11}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,41}=sqrt(subject',num2str(i),'_AccGyro{:,10}.^2 + subject',num2str(i),'_AccGyro{:,12}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,42}=sqrt(subject',num2str(i),'_AccGyro{:,11}.^2 + subject',num2str(i),'_AccGyro{:,12}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,43}=sqrt(subject',num2str(i),'_AccGyro{:,13}.^2 + subject',num2str(i),'_AccGyro{:,14}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,44}=sqrt(subject',num2str(i),'_AccGyro{:,13}.^2 + subject',num2str(i),'_AccGyro{:,15}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,45}=sqrt(subject',num2str(i),'_AccGyro{:,14}.^2 + subject',num2str(i),'_AccGyro{:,15}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,46}=sqrt(subject',num2str(i),'_AccGyro{:,16}.^2 + subject',num2str(i),'_AccGyro{:,17}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,47}=sqrt(subject',num2str(i),'_AccGyro{:,16}.^2 + subject',num2str(i),'_AccGyro{:,18}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,48}=sqrt(subject',num2str(i),'_AccGyro{:,17}.^2 + subject',num2str(i),'_AccGyro{:,18}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,49}=sqrt(subject',num2str(i),'_AccGyro{:,19}.^2 + subject',num2str(i),'_AccGyro{:,20}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,50}=sqrt(subject',num2str(i),'_AccGyro{:,19}.^2 + subject',num2str(i),'_AccGyro{:,21}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,51}=sqrt(subject',num2str(i),'_AccGyro{:,20}.^2 + subject',num2str(i),'_AccGyro{:,21}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,52}=sqrt(subject',num2str(i),'_AccGyro{:,22}.^2 + subject',num2str(i),'_AccGyro{:,23}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,53}=sqrt(subject',num2str(i),'_AccGyro{:,22}.^2 + subject',num2str(i),'_AccGyro{:,24}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,54}=sqrt(subject',num2str(i),'_AccGyro{:,23}.^2 + subject',num2str(i),'_AccGyro{:,24}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,55}=sqrt(subject',num2str(i),'_AccGyro{:,25}.^2 + subject',num2str(i),'_AccGyro{:,26}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,56}=sqrt(subject',num2str(i),'_AccGyro{:,25}.^2 + subject',num2str(i),'_AccGyro{:,27}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,57}=sqrt(subject',num2str(i),'_AccGyro{:,26}.^2 + subject',num2str(i),'_AccGyro{:,27}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,58}=sqrt(subject',num2str(i),'_AccGyro{:,28}.^2 + subject',num2str(i),'_AccGyro{:,29}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,59}=sqrt(subject',num2str(i),'_AccGyro{:,28}.^2 + subject',num2str(i),'_AccGyro{:,30}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,60}=sqrt(subject',num2str(i),'_AccGyro{:,29}.^2 + subject',num2str(i),'_AccGyro{:,30}.^2 );'])
    eval(['subject',num2str(i),'_AccGyro{:,61}=sqrt(subject',num2str(i),'_AccGyro{:,1}.^2 + subject',num2str(i),'_AccGyro{:,2}.^2 + subject',num2str(i),'_AccGyro{:,3}.^2);'])
    eval(['subject',num2str(i),'_AccGyro{:,62}=sqrt(subject',num2str(i),'_AccGyro{:,4}.^2 + subject',num2str(i),'_AccGyro{:,5}.^2 + subject',num2str(i),'_AccGyro{:,6}.^2);'])
    eval(['subject',num2str(i),'_AccGyro{:,63}=sqrt(subject',num2str(i),'_AccGyro{:,7}.^2 + subject',num2str(i),'_AccGyro{:,8}.^2 + subject',num2str(i),'_AccGyro{:,9}.^2);'])
    eval(['subject',num2str(i),'_AccGyro{:,64}=sqrt(subject',num2str(i),'_AccGyro{:,10}.^2 + subject',num2str(i),'_AccGyro{:,11}.^2 + subject',num2str(i),'_AccGyro{:,12}.^2);'])
    eval(['subject',num2str(i),'_AccGyro{:,65}=sqrt(subject',num2str(i),'_AccGyro{:,13}.^2 + subject',num2str(i),'_AccGyro{:,14}.^2 + subject',num2str(i),'_AccGyro{:,15}.^2);'])
    eval(['subject',num2str(i),'_AccGyro{:,66}=sqrt(subject',num2str(i),'_AccGyro{:,16}.^2 + subject',num2str(i),'_AccGyro{:,17}.^2 + subject',num2str(i),'_AccGyro{:,18}.^2);'])
    eval(['subject',num2str(i),'_AccGyro{:,67}=sqrt(subject',num2str(i),'_AccGyro{:,19}.^2 + subject',num2str(i),'_AccGyro{:,20}.^2 + subject',num2str(i),'_AccGyro{:,21}.^2);'])
    eval(['subject',num2str(i),'_AccGyro{:,68}=sqrt(subject',num2str(i),'_AccGyro{:,22}.^2 + subject',num2str(i),'_AccGyro{:,23}.^2 + subject',num2str(i),'_AccGyro{:,24}.^2);'])
    eval(['subject',num2str(i),'_AccGyro{:,69}=sqrt(subject',num2str(i),'_AccGyro{:,25}.^2 + subject',num2str(i),'_AccGyro{:,26}.^2 + subject',num2str(i),'_AccGyro{:,27}.^2);'])
    eval(['subject',num2str(i),'_AccGyro{:,70}=sqrt(subject',num2str(i),'_AccGyro{:,28}.^2 + subject',num2str(i),'_AccGyro{:,29}.^2 + subject',num2str(i),'_AccGyro{:,30}.^2);'])
    
    %做label標準答案
    eval(['label_',num2str(i),' = zeros(size(subject',num2str(i),'_AccGyro,1),1);'])
    start_idx=Time(i,1)+Time(i,2)+1;
    for k=1:6
        end_idx=start_idx+Time(i,k+2)-1;
        eval(['label_',num2str(i),'(start_idx:end_idx)=k;'])
        start_idx=end_idx+1;
    end

    % --- 在這裡加入這一行來強制修剪標籤長度 ---
    eval(['label_',num2str(i),' = label_',num2str(i),'(1:size(subject',num2str(i),'_AccGyro, 1));'])
    % 👇👇👇 加上這兩行，直接將這 21 個人的原始標籤匯出成 CSV 👇👇👇
    filename_gt = sprintf('GroundTruth_Label_FS%d.csv', i);
    eval(['writematrix(label_', num2str(i), ', filename_gt);']);
    eval(['subject',num2str(i),'_AccGyro(:,71)=array2table(label_',num2str(i),'(:,1));'])
    eval(['subject',num2str(i),'_AccGyro = table2array(subject',num2str(i),'_AccGyro);'])
end

%% Windowing + Feature Extraction
WS_list=[20,25,30];
SP=10;
for WS_idx=1:1
    WS=WS_list(WS_idx);
   
    for i=1:21
        eval(['NumofWindow=fix((size(subject',num2str(i),'_AccGyro,1)-WS)/SP)+1;'])
        eval(['FT_subject',num2str(i),'=[];']);
        eval(['GT_subject',num2str(i),'=[];']);

        for a=1:NumofWindow
            interval=1+(a-1)*SP:WS+(a-1)*SP;
           for g=1:70
                % 原本的 8 個特徵 (注意位移量從 *8 變成了 *10)
                eval(['FT_subject',num2str(i),'(a,1+(g-1)*8)=mean(subject',num2str(i),'_AccGyro(interval,g));'])
                eval(['FT_subject',num2str(i),'(a,2+(g-1)*8)=std(subject',num2str(i),'_AccGyro(interval,g));'])
                eval(['FT_subject',num2str(i),'(a,3+(g-1)*8)=max(subject',num2str(i),'_AccGyro(interval,g));'])
                eval(['FT_subject',num2str(i),'(a,4+(g-1)*8)=min(subject',num2str(i),'_AccGyro(interval,g));'])
                eval(['FT_subject',num2str(i),'(a,5+(g-1)*8)=range(subject',num2str(i),'_AccGyro(interval,g));'])
                
                %換特徵:Jerk標準差
                eval(['FT_subject',num2str(i),'(a,6+(g-1)*8)=std(diff(subject',num2str(i),'_AccGyro(interval,g)));'])
                eval(['FT_subject',num2str(i),'(a,7+(g-1)*8)=skewness(subject',num2str(i),'_AccGyro(interval,g));'])
                eval(['FT_subject',num2str(i),'(a,8+(g-1)*8)=kurtosis(subject',num2str(i),'_AccGyro(interval,g));'])
                
            end
            eval(['GT_subject',num2str(i),'(a,1)=mode(subject',num2str(i),'_AccGyro(interval,71));'])
        end
        eval(['FT_GT_subject',num2str(i),'=[FT_subject',num2str(i),',GT_subject',num2str(i),'];'])
    end

    %% Cross Validation
    FT_GT=[];
    data_traintest_matrix=[];
    for i=1:21
        eval(['FT_GT=[FT_GT;FT_GT_subject',num2str(i),'];'])
        eval(['L',num2str(i),'=size(FT_GT_subject',num2str(i),',1);'])
    end
    for b=1:7
        idx_1=(b-1)*3+1;
        idx_2=(b-1)*3+2;
        idx_3=(b-1)*3+3;

        eval(['len1 = L', num2str(idx_1), ';']);
        eval(['len2 = L', num2str(idx_2), ';']);
        eval(['len3 = L', num2str(idx_3), ';']);

        total_len = len1 + len2 + len3;
        eval(['data_traintest_matrix_L',num2str(b),' = [];']);
        eval(['data_traintest_matrix_L',num2str(b),'(1:total_len, 1) = b;'])
        eval(['data_traintest_matrix=[data_traintest_matrix;data_traintest_matrix_L',num2str(b),'];'])
    end

    %% Machine Learning
    model_names = {'Random Forest', 'AdaBoost', 'Decision Tree'};
    for model_idx = 1:1
        TotalMatrix = zeros(7, 4);
        % 👇👇👇 加上這行：強制將所有 560 個特徵四捨五入到小數點後 5 位 👇👇👇
        FT_GT(:, 1:560) = round(FT_GT(:, 1:560), 5);
        % 👆👆👆 加上這行 👆👆👆
        for b=1:7
        fprintf('處理受試者 %d (排除 FS%d, FS%d, FS%d)...\n', b, (b-1)*3+1, (b-1)*3+2, (b-1)*3+3);
        test=(data_traintest_matrix==b);
        train=~test;
        FT_GT_test=FT_GT(test,:);
        % 印出第 1 筆資料的前 10 個特徵，強制使用小數點後 5 位格式 (%.5f)
        fprintf('MATLAB 前 10 個特徵: ');
        fprintf('%.5f  ', FT_GT_test(1, 1:5));
        fprintf('\n');
        FT_GT_train=FT_GT(train,:);

        Train_Y = FT_GT_train(:,561);
        Train_Y(Train_Y == 4) = 2;
        Train_Y(Train_Y == 5) = 3;
        Train_Y(Train_Y == 6) = 1;

        if model_idx == 1
            % 1. Random Forest
            model = fitcensemble(FT_GT_train(:, 1:560), Train_Y, ...
                'Method', 'Bag', 'NumLearningCycles', 500, ...
                'Learners', templateTree('MinLeafSize', 2, 'NumVariablesToSample', 40));
                
        elseif model_idx == 2
            % 2. AdaBoost
            model = fitcensemble(FT_GT_train(:, 1:560), Train_Y, ...
                'Method', 'AdaBoostM2', 'NumLearningCycles', 500, ...
                'Learners', 'Tree');
                
        elseif model_idx == 3
            % 3. Decision Tree
            model = fitctree(FT_GT_train(:, 1:560), Train_Y, ...
                'MinLeafSize', 5);
        end

        % ======= 存儲 JSON 檔案 =======
        json_filename = sprintf('model_%d.json', b);
        saveForestToJSON(model, json_filename);
        % ==============================

        predictmodel=predict(model,FT_GT_test(:,1:560));
        predictpoint=[];
        for j=1:length(predictmodel)
            predictpoint(1+(j-1)*SP:WS+(j-1)*SP,1)=predictmodel(j,1);
        end
        predictpoint = medfilt1(predictpoint, 21);
        
        idx_1=(b-1)*3+1;
        idx_2=(b-1)*3+2;
        idx_3=(b-1)*3+3;
        eval(['TrueLabel_1 = subject', num2str(idx_1), '_AccGyro(:,71);']);
        eval(['TrueLabel_2 = subject', num2str(idx_2), '_AccGyro(:,71);']);
        eval(['TrueLabel_3 = subject', num2str(idx_3), '_AccGyro(:,71);']);

        Total_True_Label = [TrueLabel_1; TrueLabel_2; TrueLabel_3];

        RealLen = length(Total_True_Label);
        PredLen = length(predictpoint);
        
        if PredLen < RealLen
            % 預測太短 -> 補齊
            predictpoint(PredLen+1 : RealLen, 1) =predictpoint(end, 1);
        elseif PredLen > RealLen
            % 預測太長 -> 切掉
            predictpoint = predictpoint(1:RealLen, 1);
        end
        Len1 = length(TrueLabel_1);
        Len2 = length(TrueLabel_2);
        Len3 = length(TrueLabel_3);
        % 👇👇👇 請把那三行 writematrix 移到這個位置 👇👇👇
        % 因為經過上面的 if 判斷後，predictpoint 的長度已經完美等於 Len1+Len2+Len3 了！
        writematrix(predictpoint(1 : Len1), sprintf('RawPred_TUG%d.csv', idx_1));
        writematrix(predictpoint(Len1+1 : Len1+Len2), sprintf('RawPred_TUG%d.csv', idx_2));
        writematrix(predictpoint(Len1+Len2+1 : Len1+Len2+Len3), sprintf('RawPred_TUG%d.csv', idx_3));
        % 👆👆👆 👆👆👆

        %後處理
        Final_Predict = predictpoint;
        
        Len1 = length(TrueLabel_1);
        Len2 = length(TrueLabel_2);
        Len3 = length(TrueLabel_3);
        Start_Idx = [1, Len1+1, Len1+Len2+1];
        End_Idx   = [Len1, Len1+Len2, Len1+Len2+Len3];
        
        Subj_Indices = [idx_1, idx_2, idx_3]; 
        
        for t = 1:3
            idx_range = Start_Idx(t) : End_Idx(t);
            segment = Final_Predict(idx_range);
            seg_len = length(segment);
            
       
            curr_subj = Subj_Indices(t);
            eval(['Raw_Acc = subject', num2str(curr_subj), '_AccGyro(1:length(idx_range), 61);']);
            Physical_Std = movstd(Raw_Acc, 24);
            
            d_seg = diff([0; segment ~= 0; 0]);
            starts = find(d_seg == 1);
            ends = find(d_seg == -1) - 1;
            for k = 1:length(starts)
                blob_len = ends(k) - starts(k) + 1;
                if blob_len < 80
                    segment(starts(k):ends(k)) = 0; 
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
            
            if Sit_Count > 2
       
                Active_End = Model_End;
               
                Extend_Limit = 60; 
                for ext = 1:Extend_Limit
                    check_idx = Active_End + ext;
                    if check_idx > seg_len, break; end
                    
                    if Physical_Std(check_idx) < 0.10
                         segment(check_idx) = 1; % 視為坐下
                         Active_End = check_idx; % 更新結束點
                    else
                         break; % 一旦動了就停止
                    end
                end
                
                sit_indices = find(segment == 1);
                Last_Sit_Start = seg_len; 
                if ~isempty(sit_indices)
                    diff_sit = diff(sit_indices);
                    break_sit = [0; find(diff_sit > 1); length(sit_indices)];
                    Last_Sit_Start = sit_indices(break_sit(end-1) + 1);
                end
                
                Base_Sit_Len = 85;
                Base_Turn_Len = 50;
                
                Force_Turn_End   = Last_Sit_Start - 1;
                Force_Turn_Start = max(1, Last_Sit_Start - Base_Turn_Len); 
                
                Safety_Margin = 14;
                for shift = 0 : (Base_Turn_Len - Safety_Margin)
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
                
                if Last_Sit_Start < Active_End
                    segment(Last_Sit_Start : Active_End) = 1;
                end
                
                if Active_End < seg_len
                    segment(Active_End + 1 : end) = 0;
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
                Walk_Energy_Threshold = 0.10;
                High_Energy_Idx = find(Physical_Std > Walk_Energy_Threshold);
                
                % 1. 確保 Walk_End (走路結束點) 是正確的
                if ~isempty(High_Energy_Idx)
                    Walk_End = High_Energy_Idx(end);
                else
                    Walk_End = Model_End;
                end
                
                % 2. 坐下動作應該在「走路結束之後」才發生
                Rescue_Sit_Len = 60; 
                Active_End = min(seg_len, Walk_End + Rescue_Sit_Len);
                
                % 先把坐下之後的所有雜訊清空 (切斷長尾)
                if Active_End < seg_len
                    segment(Active_End + 1 : end) = 0;
                end
                % 填入坐下 (1)
                if Walk_End < Active_End
                    segment(Walk_End + 1 : Active_End) = 1;
                end
                
                % 3. 轉身動作應該在「走路結束之前」發生
                Rescue_Turn_Len = 30;
                Rescue_Turn_Start = max(Active_Start, Walk_End - Rescue_Turn_Len + 1);
                
                if Walk_End > Rescue_Turn_Start
                    segment(Rescue_Turn_Start : Walk_End) = 3;
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
                if val == 2, segment(k) = 4;
                elseif val == 1, segment(k) = 6;
                elseif val == 3, segment(k) = 5;
                end
            end
            
            for k = Active_Start : SplitPoint
                if segment(k) >= 4
                    segment(k) = segment(k) - 3;
                end
            end
            
            d_final = diff([0; segment ~= 0; 0]); 
            s_final = find(d_final == 1);
            e_final = find(d_final == -1) - 1;
            for k = 1:length(s_final)
                if (e_final(k) - s_final(k) + 1) < 20
                    segment(s_final(k):e_final(k)) = 0;
                end
            end
            
            Final_Predict(idx_range) = segment;
        end


        Tolerance = 0; 
        Relaxed_Pred = Final_Predict; 

        d_true = diff([0; Total_True_Label(:); 0]);
        boundary_idx = find(d_true ~= 0);

        % 2. 在每一個切換點的前後展開保護區
        for bound_i = 1:length(boundary_idx)
            idx = boundary_idx(bound_i);
            
            % 劃定 +- 15 點的視窗 (使用 max/min 防止超出陣列邊界)
            win_start = max(1, idx - Tolerance);
            win_end = min(length(Total_True_Label), idx + Tolerance);
            
            % 找出這個交界處涉及的「合法動作」
            valid_labels = unique(Total_True_Label(win_start:win_end));
            
            % 掃描保護區內的模型預測值，予以赦免對齊
            for w = win_start:win_end
                if ismember(Relaxed_Pred(w), valid_labels)
                    Relaxed_Pred(w) = Total_True_Label(w);
                end
            end
        end

        % 🟢 修改這裡：強制給定 0~6 分類計算混淆矩陣，解決少動作縮水報錯，並補上印出指令
            classes = 0:6;
            eval(['Confusionmatrix',num2str(b),'=confusionmat(Total_True_Label, Relaxed_Pred, ''Order'', classes);'])
            eval(['CM = Confusionmatrix',num2str(b),';'])
            
            matrix_size = size(CM, 1);
            Acc = sum(diag(CM)) / sum(CM(:));
            
            Sen = zeros(matrix_size, 1);
            Pre = zeros(1, matrix_size);
            for idx_i = 1:matrix_size
                if sum(CM(idx_i,:)) > 0, Sen(idx_i,1) = CM(idx_i,idx_i) / sum(CM(idx_i,:)); else, Sen(idx_i,1) = NaN; end
                if sum(CM(:,idx_i)) > 0, Pre(1,idx_i) = CM(idx_i,idx_i) / sum(CM(:,idx_i)); else, Pre(1,idx_i) = NaN; end
            end
            
            P_vec = Pre';
            R_vec = Sen;
            Denominator = P_vec + R_vec;
            F1_vec = zeros(matrix_size, 1);
            for idx_i = 1:matrix_size
                if Denominator(idx_i) > 0 && ~isnan(Denominator(idx_i))
                    F1_vec(idx_i) = 2 * (P_vec(idx_i) * R_vec(idx_i)) / Denominator(idx_i);
                else
                    F1_vec(idx_i) = NaN;
                end
            end
            
            TotalMatrix(b,1) = Acc;
            TotalMatrix(b,2) = mean(Sen(:,1), 'omitnan');
            TotalMatrix(b,3) = mean(Pre(1,:), 'omitnan');
            TotalMatrix(b,4) = mean(F1_vec, 'omitnan');
            
            % 👇👇👇 這裡就是為你加上去印出結果的環節 👇👇👇
            fprintf('\n==========================================\n');
            fprintf('第 %d 位受試者當作測試集 (包含 TUG %d, %d, %d)\n', b, idx_1, idx_2, idx_3);
            fprintf('準確率 (Accuracy) : %.2f%%\n', TotalMatrix(b,1) * 100);
            fprintf('靈敏度 (Recall)   : %.2f%%\n', TotalMatrix(b,2) * 100);
            fprintf('精確率 (Precision): %.2f%%\n', TotalMatrix(b,3) * 100);
            fprintf('F1-Score          : %.4f\n', TotalMatrix(b,4));
            fprintf('==========================================\n');
            
            figure; plot(Total_True_Label); hold on; plot(Final_Predict); title(['Subject ', num2str(b)]); legend('True', 'Pred');
        end
        
        col_start = (model_idx - 1) * 4 + 1;
        col_end   = model_idx * 4;
        total(WS_idx, col_start:col_end) = mean(TotalMatrix, 1);
    end
end
function saveForestToJSON(model, filename)
    NumTrees = length(model.Trained);
    forestStruct = cell(NumTrees, 1);
    for i = 1:NumTrees
        forestStruct{i} = parseTree(model.Trained{i}, 1);
    end
    final.trees = forestStruct;
    
    % --- 這裡是關鍵修正 ---
    % 1. 先轉成 JSON 字串
    jsonString = jsonencode(final);
    
    % 2. 使用正規表達式 (regexprep) 搜尋所有的數字，並強制轉為 15 位小數精度
    % 這個指令會把 JSON 裡面的每一個浮點數都變成 %.15f 的高精度字串
    jsonString = regexprep(jsonString, '(\d+\.\d+)', '${sprintf(''%.15f'', str2double($1))}');
    
    % 3. 寫入檔案
    fid = fopen(filename, 'w');
    fprintf(fid, '%s', jsonString);
    fclose(fid);
end

function node = parseTree(tree, idx)
    isBranch = tree.IsBranchNode(idx);
    if ~isBranch
        node.isLeaf = true;
        lbl = tree.NodeClass(idx);
        if iscategorical(lbl) || iscell(lbl), node.label = double(string(lbl));
        else, node.label = double(lbl); end
        
        % 👇 核心修改：把這片葉節點的「各類別機率」一起匯出
        node.probabilities = tree.ClassProbability(idx, :);
        
        node.splitVarIdx = -1; node.threshold = 0;
        node.left = []; node.right = [];
    else
        node.isLeaf = false;
        node.label = -1;
        node.splitVarIdx = tree.CutPredictorIndex(idx) - 1; 
        node.threshold = tree.CutPoint(idx);
        node.left = parseTree(tree, tree.Children(idx, 1));
        node.right = parseTree(tree, tree.Children(idx, 2));
    end
end