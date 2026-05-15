export type KeymapSet = Parameters<typeof glide.keymaps.set>;

export type SimpleKeymapTuple = [
  modes: KeymapSet['0'],
  keys: KeymapSet['1'],
  command: KeymapSet['2'],
  description: string,
];
