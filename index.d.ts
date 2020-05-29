interface RNFileViewerOptions {
  displayName?: string;
  showAppsSuggestions?: boolean;
  showOpenWithDialog?: boolean;
  onDismiss?(): any;
}

export function open(
  path: string,
  options?: RNFileViewerOptions | string
): Promise<void>;

export function getThumbnail(path: string): Promise<String>;
