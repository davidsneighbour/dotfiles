import { useRef, useState } from "react";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

export function Combobox<T>({
  id,
  value,
  onValueChange,
  items,
  getKey,
  renderItem,
  onSelect,
  placeholder,
  required,
  emptyMessage,
}: {
  id?: string;
  value: string;
  onValueChange: (value: string) => void;
  items: T[];
  getKey: (item: T) => string;
  renderItem: (item: T, active: boolean) => React.ReactNode;
  onSelect: (item: T) => void;
  placeholder?: string;
  required?: boolean;
  emptyMessage?: string;
}) {
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);
  const blurTimeout = useRef<ReturnType<typeof setTimeout> | undefined>(
    undefined,
  );

  const close = () => {
    blurTimeout.current = setTimeout(() => setOpen(false), 120);
  };
  const cancelClose = () => {
    if (blurTimeout.current !== undefined) {
      clearTimeout(blurTimeout.current);
      blurTimeout.current = undefined;
    }
  };

  const select = (item: T) => {
    cancelClose();
    onSelect(item);
    setOpen(false);
    setActiveIndex(-1);
  };

  return (
    <div className="relative">
      <Input
        id={id}
        value={value}
        placeholder={placeholder}
        required={required}
        autoComplete="off"
        onChange={(event) => {
          onValueChange(event.target.value);
          setOpen(true);
          setActiveIndex(-1);
        }}
        onFocus={() => setOpen(true)}
        onBlur={close}
        onKeyDown={(event) => {
          if (event.key === "ArrowDown") {
            event.preventDefault();
            setOpen(true);
            setActiveIndex((current) =>
              Math.min(current + 1, items.length - 1),
            );
          } else if (event.key === "ArrowUp") {
            event.preventDefault();
            setActiveIndex((current) => Math.max(current - 1, 0));
          } else if (event.key === "Enter") {
            if (open && activeIndex >= 0 && items[activeIndex] !== undefined) {
              event.preventDefault();
              select(items[activeIndex]);
            }
          } else if (event.key === "Escape") {
            setOpen(false);
            setActiveIndex(-1);
          }
        }}
      />
      {open && (items.length > 0 || emptyMessage !== undefined) && (
        <ul
          className="absolute z-50 mt-1 max-h-56 w-full overflow-y-auto rounded-md border border-border bg-popover text-popover-foreground shadow-md"
          onMouseDown={(event) => {
            event.preventDefault();
            cancelClose();
          }}
        >
          {items.length === 0 ? (
            <li className="px-2 py-1.5 text-sm text-muted-foreground">
              {emptyMessage}
            </li>
          ) : (
            items.map((item, index) => (
              <li
                key={getKey(item)}
                className={cn(
                  "cursor-default px-2 py-1.5 text-sm select-none",
                  index === activeIndex
                    ? "bg-secondary text-secondary-foreground"
                    : "hover:bg-secondary/50",
                )}
                onMouseEnter={() => setActiveIndex(index)}
                onClick={() => select(item)}
              >
                {renderItem(item, index === activeIndex)}
              </li>
            ))
          )}
        </ul>
      )}
    </div>
  );
}
