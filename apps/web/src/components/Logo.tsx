import { useState } from 'react'

/**
 * ATOLL Logo
 *
 * Renders the official logo from `/public/atoll-logo.png`. If the image
 * fails to load, nothing is rendered — we never want to show a synthetic
 * fallback that looks different from the real brand mark.
 *
 * Replace `/public/atoll-logo.png` with an updated export to swap the logo
 * everywhere in one go.
 */
interface Props {
  size?: number
  className?: string
}

export function Logo({ size = 48, className }: Props) {
  const [imgFailed, setImgFailed] = useState(false)

  if (imgFailed) {
    // Real logo not loadable — render nothing rather than a synthetic stand-in.
    // Reserve the layout space so surrounding UI doesn't jump.
    return <span style={{ display: 'inline-block', width: size, height: size }} aria-hidden />
  }

  return (
    <img
      src="/atoll-logo.png"
      alt="ATOLL"
      width={size}
      height={size}
      onError={() => setImgFailed(true)}
      className={className}
      style={{
        display: 'block',
        flexShrink: 0,
        objectFit: 'contain',
        width: size,
        height: size,
      }}
    />
  )
}
