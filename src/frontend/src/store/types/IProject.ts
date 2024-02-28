import {
  downloadProjectFormLoadingType,
  projectDashboardDetailTypes,
  projectInfoType,
  projectTaskBoundriesType,
} from '@/models/project/projectModel';

export type ProjectStateTypes = {
  projectLoading: boolean;
  projectTaskBoundries: projectTaskBoundriesType[];
  newProjectTrigger: boolean;
  projectInfo: projectInfoType | Record<string, any>;
  projectSubmissionLoading: boolean;
  projectSubmission: [];
  projectDataExtractLoading: boolean;
  downloadProjectFormLoading: downloadProjectFormLoadingType;
  generateProjectTilesLoading: boolean;
  tilesList: tilesListTypes[];
  tilesListLoading: boolean;
  downloadTilesLoading: boolean;
  downloadDataExtractLoading: boolean;
  taskModalStatus: boolean;
  mobileFooterSelection: string;
  geolocationStatus: boolean;
  projectDetailsLoading: boolean;
  projectDashboardDetail: projectDashboardDetailTypes;
  projectDashboardLoading: boolean;
};

type tilesListTypes = {
  id: number;
  project_id: number;
  status: string;
  tile_source: string;
};
