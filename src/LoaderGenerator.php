<?php

declare(strict_types=1);

namespace MuLoader;

use Composer\Composer;
use Composer\IO\IOInterface;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use SplFileInfo;

final class LoaderGenerator
{
    private Composer $composer;
    private IOInterface $io;

    public function __construct(Composer $composer, IOInterface $io)
    {
        $this->composer = $composer;
        $this->io = $io;
    }

    public function generate(): void
    {
        $rootDir = $this->projectRootDir();
        $extra = $this->composer->getPackage()->getExtra();
        $config = isset($extra['mu-loader']) && \is_array($extra['mu-loader']) ? $extra['mu-loader'] : [];

        $paths = $this->resolvePaths($rootDir, $config['paths'] ?? ['wp-content/mu-plugins']);
        $output = $this->resolveOutputPath($rootDir, $paths, $config['output'] ?? null);
        $exclude = $this->normalizeExclude($rootDir, $config['exclude'] ?? []);
        $exclude[] = $this->normalizePath($output);

        $files = $this->discoverPhpFiles($paths, $exclude);
        $contents = $this->buildLoaderFile($output, $files);

        $dir = \dirname($output);
        if (!\is_dir($dir) && !@\mkdir($dir, 0775, true) && !\is_dir($dir)) {
            $this->io->writeError('<warning>[mu-loader] Could not create output directory: ' . $dir . '</warning>');

            return;
        }

        \file_put_contents($output, $contents);

        $this->io->write('<info>[mu-loader] Generated ' . $this->relativeToRoot($rootDir, $output) . ' (' . \count($files) . ' files)</info>');
    }

    private function projectRootDir(): string
    {
        $cwd = \getcwd();
        if (\is_string($cwd) && $cwd !== '') {
            return $this->normalizePath($cwd);
        }

        return $this->normalizePath((string) \dirname((string) $this->composer->getConfig()->get('vendor-dir')));
    }

    /**
     * @param mixed $configuredPaths
     * @return array<int, string>
     */
    private function resolvePaths(string $rootDir, $configuredPaths): array
    {
        $paths = \is_array($configuredPaths) ? $configuredPaths : [$configuredPaths];
        $result = [];

        foreach ($paths as $path) {
            if (!\is_string($path) || $path === '') {
                continue;
            }

            $absolute = $this->toAbsolutePath($rootDir, $path);
            $normalized = $this->normalizePath($absolute);
            if (\is_dir($normalized)) {
                $result[] = $normalized;
            }
        }

        return \array_values(\array_unique($result));
    }

    /**
     * @param array<int, string> $paths
     * @param mixed $configuredOutput
     */
    private function resolveOutputPath(string $rootDir, array $paths, $configuredOutput): string
    {
        if (\is_string($configuredOutput) && $configuredOutput !== '') {
            return $this->normalizePath($this->toAbsolutePath($rootDir, $configuredOutput));
        }

        $base = $paths[0] ?? $this->normalizePath($rootDir . '/wp-content/mu-plugins');

        return $this->normalizePath($base . '/000-mu-loader.php');
    }

    /**
     * @param mixed $configuredExclude
     * @return array<int, string>
     */
    private function normalizeExclude(string $rootDir, $configuredExclude): array
    {
        $exclude = \is_array($configuredExclude) ? $configuredExclude : [$configuredExclude];
        $normalized = [];

        foreach ($exclude as $path) {
            if (\is_string($path) && $path !== '') {
                $normalized[] = $this->normalizePath($this->toAbsolutePath($rootDir, $path));
            }
        }

        return $normalized;
    }

    /**
     * @param array<int, string> $paths
     * @param array<int, string> $exclude
     * @return array<int, string>
     */
    private function discoverPhpFiles(array $paths, array $exclude): array
    {
        $files = [];
        $excludeSet = \array_flip($exclude);

        foreach ($paths as $path) {
            $iterator = new RecursiveIteratorIterator(
                new RecursiveDirectoryIterator($path, RecursiveDirectoryIterator::SKIP_DOTS)
            );

            /** @var SplFileInfo $item */
            foreach ($iterator as $item) {
                if (!$item->isFile()) {
                    continue;
                }

                if (\strtolower($item->getExtension()) !== 'php') {
                    continue;
                }

                $filename = $item->getFilename();
                if (\str_starts_with($filename, '.')) {
                    continue;
                }

                $real = $this->normalizePath((string) $item->getPathname());
                if (isset($excludeSet[$real])) {
                    continue;
                }

                $files[] = $real;
            }
        }

        \sort($files);

        return \array_values(\array_unique($files));
    }

    /**
     * @param array<int, string> $files
     */
    private function buildLoaderFile(string $output, array $files): string
    {
        $lines = [
            '<?php',
            '',
            'declare(strict_types=1);',
            '',
            '// This file is generated by mu-loader. Do not edit manually.',
            '',
        ];

        foreach ($files as $file) {
            $relative = $this->relativePath(\dirname($output), $file);
            $escaped = \str_replace("'", "\\'", $relative);
            $lines[] = "require_once __DIR__ . '/{$escaped}';";
        }

        $lines[] = '';

        return \implode("\n", $lines);
    }

    private function relativePath(string $fromDir, string $toFile): string
    {
        $from = \explode('/', \trim($this->normalizePath($fromDir), '/'));
        $to = \explode('/', \trim($this->normalizePath($toFile), '/'));

        while ($from !== [] && $to !== [] && $from[0] === $to[0]) {
            \array_shift($from);
            \array_shift($to);
        }

        $ups = \array_fill(0, \count($from), '..');

        return \implode('/', \array_merge($ups, $to));
    }

    private function relativeToRoot(string $rootDir, string $path): string
    {
        $rootDir = \rtrim($this->normalizePath($rootDir), '/') . '/';
        $path = $this->normalizePath($path);

        if (\str_starts_with($path, $rootDir)) {
            return \substr($path, \strlen($rootDir));
        }

        return $path;
    }

    private function toAbsolutePath(string $rootDir, string $path): string
    {
        if ($this->isAbsolutePath($path)) {
            return $path;
        }

        return $rootDir . '/' . $path;
    }

    private function isAbsolutePath(string $path): bool
    {
        return \str_starts_with($path, '/') || (bool) \preg_match('/^[A-Za-z]:[\\\\\\/]/', $path);
    }

    private function normalizePath(string $path): string
    {
        $path = \str_replace('\\', '/', $path);
        $path = \preg_replace('#/+#', '/', $path) ?: $path;

        $segments = [];
        foreach (\explode('/', $path) as $segment) {
            if ($segment === '' || $segment === '.') {
                continue;
            }

            if ($segment === '..') {
                \array_pop($segments);
                continue;
            }

            $segments[] = $segment;
        }

        $prefix = \str_starts_with($path, '/') ? '/' : '';

        if (\preg_match('/^[A-Za-z]:/', $path) === 1) {
            $prefix = \substr($path, 0, 2) . '/';
        }

        return $prefix . \implode('/', $segments);
    }
}
